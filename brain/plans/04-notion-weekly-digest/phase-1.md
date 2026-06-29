# notion-weekly-digest — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a manually-run Python pipeline that collects dev news (GeekNews + Hacker News), ranks by popularity, summarizes the best 5–8 in Korean via local GPT-5.5 (`codex`), and renders them as Notion reference-article bullets to a local markdown file. Claude then posts that markdown to a Joh's Notion staging page via the Notion MCP (operational step, not script code).

**Architecture:** Self-contained `notion_weekly_digest` package. Source fetchers normalize to a common `Article` model; `rank` selects per-source candidates; `fetch_content` pulls body text; `summarize` shells out to `codex exec` and parses sentinel-wrapped output into `Summary` objects; `render` produces the exact bullet format; `state` dedupes across weeks; `run` orchestrates and writes `output/digest-YYYY-MM-DD.md`. Notion writing is done by Claude via MCP after the script runs.

**Tech Stack:** Python 3.11+, feedparser (RSS), requests (HTTP), beautifulsoup4 (text extraction), pytest (tests), `codex` CLI (GPT-5.5 summarization).

## Global Constraints

- Python `>=3.11`.
- Runtime deps, exact floors: `feedparser>=6.0.0`, `requests>=2.31.0`, `beautifulsoup4>=4.12.0`.
- Dev deps: `pytest>=8.0.0`.
- All summaries written in **Korean**.
- Output markdown format is **exact**: top bullet `- [제목](URL)`, then **tab-indented** sub-bullets — line 1 = 한 줄 요약, line 2 = 핵심 2~3문장, optional further lines = takeaway/참고. Nesting uses a literal tab (`\t`).
- GPT-5.5 summarization happens **only** via local `codex exec` subprocess. No OpenAI/Anthropic API key.
- Notion writing is **not** in the script — Claude does it via Notion MCP (documented in Task 10 runbook).
- Manual run only. No cron/scheduler.
- App lives at `apps/notion-weekly-digest`, its own git repo (per workspace rule: never create projects outside `apps/`).
- TDD throughout. **No unit test may make a real network call or invoke `codex`** — fixtures and injected fakes only.
- All paths below are relative to `apps/notion-weekly-digest/`. All `git` commands run inside that app repo.

## File Structure

```
apps/notion-weekly-digest/
├── pyproject.toml
├── .gitignore
├── README.md
├── CLAUDE.md
├── notion_weekly_digest/
│   ├── __init__.py
│   ├── models.py            # Article, Summary dataclasses (shared interface)
│   ├── rank.py              # per-source popularity ranking + dedup
│   ├── state.py             # seen-URL persistence (cross-week dedup)
│   ├── fetch_content.py     # article body → plain text
│   ├── render.py            # Summary[] → Notion bullet markdown
│   ├── summarize.py         # prompt build + codex exec + output parse
│   ├── run.py               # pipeline orchestration
│   └── sources/
│       ├── __init__.py
│       ├── geeknews.py      # news.hada.io RSS → Article[]
│       └── hackernews.py    # HN Algolia API → Article[]
├── tests/
│   ├── __init__.py
│   ├── fixtures/
│   │   ├── geeknews_rss.xml
│   │   └── hn_algolia.json
│   ├── test_models.py
│   ├── test_geeknews.py
│   ├── test_hackernews.py
│   ├── test_rank.py
│   ├── test_state.py
│   ├── test_fetch_content.py
│   ├── test_render.py
│   ├── test_summarize.py
│   └── test_run.py
├── output/                  # gitignored (digest-*.md)
└── state/                   # gitignored (seen.json)
```

---

### Task 1: Scaffold app + project setup + models

**Files:**
- Scaffold: `apps/notion-weekly-digest/` (own git repo)
- Create: `pyproject.toml`, `.gitignore`, `notion_weekly_digest/__init__.py`, `notion_weekly_digest/sources/__init__.py`, `tests/__init__.py`
- Create: `notion_weekly_digest/models.py`
- Test: `tests/test_models.py`

**Interfaces:**
- Produces: `Article(title:str, url:str, source:str, points:int=0, comments:int=0, published_at:datetime|None=None)` and `Summary(title:str, url:str, source:str, one_liner:str, detail:str, extra:list[str]=[])`. Every later task imports these.

- [ ] **Step 1: Scaffold the app**

Use the `new-app` skill to scaffold `notion-weekly-digest` (creates `apps/notion-weekly-digest/` as its own git repo, an app-level CLAUDE.md, and registers it in `brain/apps.md`). If running the skill is not possible in-context, scaffold manually:

```bash
mkdir -p apps/notion-weekly-digest && cd apps/notion-weekly-digest && git init
mkdir -p notion_weekly_digest/sources tests/fixtures output state
```

- [ ] **Step 2: Write `pyproject.toml`**

```toml
[project]
name = "notion-weekly-digest"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "feedparser>=6.0.0",
    "requests>=2.31.0",
    "beautifulsoup4>=4.12.0",
]

[project.optional-dependencies]
dev = ["pytest>=8.0.0"]

[build-system]
requires = ["setuptools>=68"]
build-backend = "setuptools.build_meta"

[tool.setuptools]
packages = ["notion_weekly_digest", "notion_weekly_digest.sources"]
```

- [ ] **Step 3: Write `.gitignore`**

```gitignore
__pycache__/
*.egg-info/
*.pyc
.pytest_cache/
output/
state/
.venv/
```

- [ ] **Step 4: Create empty package markers**

Create empty `notion_weekly_digest/__init__.py`, `notion_weekly_digest/sources/__init__.py`, `tests/__init__.py`. Add `output/.gitkeep` and `state/.gitkeep` so the dirs exist.

- [ ] **Step 5: Write the failing test** — `tests/test_models.py`

```python
from notion_weekly_digest.models import Article, Summary


def test_article_defaults():
    a = Article(title="t", url="u", source="GeekNews")
    assert a.points == 0
    assert a.comments == 0
    assert a.published_at is None


def test_summary_extra_is_independent_per_instance():
    s1 = Summary(title="t1", url="u1", source="s", one_liner="o", detail="d")
    s2 = Summary(title="t2", url="u2", source="s", one_liner="o", detail="d")
    s1.extra.append("x")
    assert s2.extra == []
```

- [ ] **Step 6: Run test to verify it fails**

Run: `pip install -e ".[dev]" && pytest tests/test_models.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'notion_weekly_digest.models'`

- [ ] **Step 7: Write `notion_weekly_digest/models.py`**

```python
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime


@dataclass
class Article:
    title: str
    url: str
    source: str  # "GeekNews" | "Hacker News"
    points: int = 0
    comments: int = 0
    published_at: datetime | None = None


@dataclass
class Summary:
    title: str
    url: str
    source: str
    one_liner: str
    detail: str
    extra: list[str] = field(default_factory=list)
```

- [ ] **Step 8: Run test to verify it passes**

Run: `pytest tests/test_models.py -v`
Expected: PASS (2 passed)

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "chore: scaffold notion-weekly-digest + Article/Summary models"
```

---

### Task 2: GeekNews source

**Files:**
- Create: `notion_weekly_digest/sources/geeknews.py`
- Create: `tests/fixtures/geeknews_rss.xml`
- Test: `tests/test_geeknews.py`

**Interfaces:**
- Consumes: `Article` from `notion_weekly_digest.models`.
- Produces: `parse_feed(raw: str) -> list[Article]` (pure, testable) and `fetch(url: str = GEEKNEWS_RSS) -> list[Article]` (network). `GEEKNEWS_RSS: str` module constant.

- [ ] **Step 1: Capture a real fixture and confirm the feed URL**

Run: `curl -sL https://news.hada.io/rss/news -o tests/fixtures/geeknews_rss.xml && head -40 tests/fixtures/geeknews_rss.xml`
Expected: RSS 2.0 XML with `<item>` elements containing `<title>` and `<link>`. If this URL 404s, try `https://news.hada.io/rss/topics`; use whichever returns items and set `GEEKNEWS_RSS` accordingly. Inspect whether `<description>`/`<summary>` contains points/comments text; the parser extracts them only if present.

- [ ] **Step 2: Write the failing test** — `tests/test_geeknews.py`

```python
from pathlib import Path

from notion_weekly_digest.sources import geeknews

FIXTURE = Path(__file__).parent / "fixtures" / "geeknews_rss.xml"


def test_parse_feed_returns_articles_with_title_and_link():
    raw = FIXTURE.read_text(encoding="utf-8")
    articles = geeknews.parse_feed(raw)
    assert len(articles) >= 1
    first = articles[0]
    assert first.title
    assert first.url.startswith("http")
    assert first.source == "GeekNews"


def test_parse_feed_extracts_points_when_present():
    raw = """<?xml version="1.0"?><rss><channel>
    <item><title>Sample</title><link>https://e.com/a</link>
    <description>120 points | 30 comments</description></item>
    </channel></rss>"""
    articles = geeknews.parse_feed(raw)
    assert articles[0].points == 120
    assert articles[0].comments == 30
```

- [ ] **Step 3: Run test to verify it fails**

Run: `pytest tests/test_geeknews.py -v`
Expected: FAIL — `ModuleNotFoundError` / `AttributeError: module 'geeknews' has no attribute 'parse_feed'`

- [ ] **Step 4: Write `notion_weekly_digest/sources/geeknews.py`**

```python
from __future__ import annotations

import re

import feedparser

from ..models import Article

GEEKNEWS_RSS = "https://news.hada.io/rss/news"

_POINTS_RE = re.compile(r"(\d+)\s*points?", re.IGNORECASE)
_COMMENTS_RE = re.compile(r"(\d+)\s*comments?", re.IGNORECASE)


def parse_feed(raw: str) -> list[Article]:
    feed = feedparser.parse(raw)
    articles: list[Article] = []
    for entry in feed.entries:
        title = (getattr(entry, "title", "") or "").strip()
        link = (getattr(entry, "link", "") or "").strip()
        if not title or not link:
            continue
        blob = (getattr(entry, "summary", "") or "")
        pm = _POINTS_RE.search(blob)
        cm = _COMMENTS_RE.search(blob)
        articles.append(
            Article(
                title=title,
                url=link,
                source="GeekNews",
                points=int(pm.group(1)) if pm else 0,
                comments=int(cm.group(1)) if cm else 0,
            )
        )
    return articles


def fetch(url: str = GEEKNEWS_RSS) -> list[Article]:
    import requests

    resp = requests.get(
        url, timeout=20, headers={"User-Agent": "notion-weekly-digest/1.0"}
    )
    resp.raise_for_status()
    return parse_feed(resp.text)
```

- [ ] **Step 5: Run test to verify it passes**

Run: `pytest tests/test_geeknews.py -v`
Expected: PASS (2 passed)

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: GeekNews RSS source"
```

---

### Task 3: Hacker News source

**Files:**
- Create: `notion_weekly_digest/sources/hackernews.py`
- Create: `tests/fixtures/hn_algolia.json`
- Test: `tests/test_hackernews.py`

**Interfaces:**
- Consumes: `Article` from `notion_weekly_digest.models`.
- Produces: `parse_hits(payload: str | dict) -> list[Article]` (pure) and `fetch(days:int=7, hits:int=50, now:float|None=None) -> list[Article]` (network). `ALGOLIA_URL: str` constant.

- [ ] **Step 1: Create fixture** — `tests/fixtures/hn_algolia.json`

```json
{
  "hits": [
    {"title": "Show HN: A tiny database", "url": "https://example.com/db",
     "points": 412, "num_comments": 88, "objectID": "111", "created_at_i": 1719600000},
    {"title": "Ask HN: Career advice", "url": null,
     "points": 95, "num_comments": 210, "objectID": "222", "created_at_i": 1719500000}
  ]
}
```

- [ ] **Step 2: Write the failing test** — `tests/test_hackernews.py`

```python
import json
from pathlib import Path

from notion_weekly_digest.sources import hackernews

FIXTURE = Path(__file__).parent / "fixtures" / "hn_algolia.json"


def test_parse_hits_maps_fields():
    data = json.loads(FIXTURE.read_text(encoding="utf-8"))
    articles = hackernews.parse_hits(data)
    assert len(articles) == 2
    assert articles[0].source == "Hacker News"
    assert articles[0].points == 412
    assert articles[0].comments == 88
    assert articles[0].url == "https://example.com/db"


def test_parse_hits_falls_back_to_hn_item_url_when_url_missing():
    data = json.loads(FIXTURE.read_text(encoding="utf-8"))
    articles = hackernews.parse_hits(data)
    assert articles[1].url == "https://news.ycombinator.com/item?id=222"
```

- [ ] **Step 3: Run test to verify it fails**

Run: `pytest tests/test_hackernews.py -v`
Expected: FAIL — `AttributeError: module ... has no attribute 'parse_hits'`

- [ ] **Step 4: Write `notion_weekly_digest/sources/hackernews.py`**

```python
from __future__ import annotations

import json
from datetime import datetime, timezone

from ..models import Article

ALGOLIA_URL = "https://hn.algolia.com/api/v1/search"


def parse_hits(payload: str | dict) -> list[Article]:
    data = json.loads(payload) if isinstance(payload, str) else payload
    articles: list[Article] = []
    for hit in data.get("hits", []):
        title = (hit.get("title") or "").strip()
        if not title:
            continue
        url = hit.get("url") or (
            f"https://news.ycombinator.com/item?id={hit.get('objectID')}"
        )
        ts = hit.get("created_at_i")
        published = (
            datetime.fromtimestamp(ts, tz=timezone.utc) if ts else None
        )
        articles.append(
            Article(
                title=title,
                url=url,
                source="Hacker News",
                points=int(hit.get("points") or 0),
                comments=int(hit.get("num_comments") or 0),
                published_at=published,
            )
        )
    return articles


def fetch(days: int = 7, hits: int = 50, now: float | None = None) -> list[Article]:
    import time

    import requests

    now_ts = int(now if now is not None else time.time())
    since = now_ts - days * 86400
    params = {
        "tags": "story",
        "numericFilters": f"created_at_i>{since}",
        "hitsPerPage": hits,
    }
    resp = requests.get(ALGOLIA_URL, params=params, timeout=20)
    resp.raise_for_status()
    return parse_hits(resp.json())
```

- [ ] **Step 5: Run test to verify it passes**

Run: `pytest tests/test_hackernews.py -v`
Expected: PASS (2 passed)

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: Hacker News (Algolia) source"
```

---

### Task 4: Ranking

**Files:**
- Create: `notion_weekly_digest/rank.py`
- Test: `tests/test_rank.py`

**Interfaces:**
- Consumes: `Article`.
- Produces: `popularity(a: Article) -> int` and `rank_candidates(articles: list[Article], per_source: int = 15) -> list[Article]`. Dedupes by URL, then returns the top `per_source` by popularity **from each source** (guarantees both sources are represented even though GeekNews points may be 0).

- [ ] **Step 1: Write the failing test** — `tests/test_rank.py`

```python
from notion_weekly_digest.models import Article
from notion_weekly_digest.rank import rank_candidates


def _a(url, source, points):
    return Article(title=url, url=url, source=source, points=points)


def test_rank_dedupes_by_url():
    items = [_a("u1", "Hacker News", 10), _a("u1", "Hacker News", 10)]
    assert len(rank_candidates(items)) == 1


def test_rank_keeps_top_per_source():
    items = [
        _a("h1", "Hacker News", 100),
        _a("h2", "Hacker News", 50),
        _a("h3", "Hacker News", 10),
        _a("g1", "GeekNews", 0),
    ]
    out = rank_candidates(items, per_source=2)
    hn = [a for a in out if a.source == "Hacker News"]
    gn = [a for a in out if a.source == "GeekNews"]
    assert [a.url for a in hn] == ["h1", "h2"]   # top 2 by points
    assert [a.url for a in gn] == ["g1"]          # GeekNews still represented
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_rank.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'notion_weekly_digest.rank'`

- [ ] **Step 3: Write `notion_weekly_digest/rank.py`**

```python
from __future__ import annotations

from .models import Article


def popularity(a: Article) -> int:
    return a.points + a.comments


def rank_candidates(articles: list[Article], per_source: int = 15) -> list[Article]:
    seen: set[str] = set()
    by_source: dict[str, list[Article]] = {}
    for a in articles:
        if a.url in seen:
            continue
        seen.add(a.url)
        by_source.setdefault(a.source, []).append(a)

    result: list[Article] = []
    for items in by_source.values():
        items.sort(key=popularity, reverse=True)
        result.extend(items[:per_source])
    return result
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_rank.py -v`
Expected: PASS (2 passed)

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: per-source popularity ranking"
```

---

### Task 5: State (cross-week dedup)

**Files:**
- Create: `notion_weekly_digest/state.py`
- Test: `tests/test_state.py`

**Interfaces:**
- Consumes: `Article`.
- Produces: `load_seen(path: str) -> set[str]`, `mark_seen(path: str, urls: list[str]) -> None`, `filter_unseen(path: str, articles: list[Article]) -> list[Article]`.

- [ ] **Step 1: Write the failing test** — `tests/test_state.py`

```python
from notion_weekly_digest.models import Article
from notion_weekly_digest import state


def test_load_seen_missing_file_returns_empty(tmp_path):
    assert state.load_seen(str(tmp_path / "nope.json")) == set()


def test_mark_then_filter(tmp_path):
    path = str(tmp_path / "seen.json")
    state.mark_seen(path, ["u1", "u2"])
    arts = [
        Article("a", "u1", "Hacker News"),
        Article("b", "u3", "GeekNews"),
    ]
    fresh = state.filter_unseen(path, arts)
    assert [a.url for a in fresh] == ["u3"]


def test_mark_seen_is_cumulative(tmp_path):
    path = str(tmp_path / "seen.json")
    state.mark_seen(path, ["u1"])
    state.mark_seen(path, ["u2"])
    assert state.load_seen(path) == {"u1", "u2"}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_state.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'notion_weekly_digest.state'`

- [ ] **Step 3: Write `notion_weekly_digest/state.py`**

```python
from __future__ import annotations

import json
import os

from .models import Article


def load_seen(path: str) -> set[str]:
    if not os.path.exists(path):
        return set()
    with open(path, encoding="utf-8") as f:
        return set(json.load(f))


def mark_seen(path: str, urls: list[str]) -> None:
    seen = load_seen(path)
    seen.update(urls)
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(sorted(seen), f, ensure_ascii=False, indent=2)


def filter_unseen(path: str, articles: list[Article]) -> list[Article]:
    seen = load_seen(path)
    return [a for a in articles if a.url not in seen]
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_state.py -v`
Expected: PASS (3 passed)

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: seen-URL state for cross-week dedup"
```

---

### Task 6: Content fetching

**Files:**
- Create: `notion_weekly_digest/fetch_content.py`
- Test: `tests/test_fetch_content.py`

**Interfaces:**
- Produces: `extract_text(html: str, max_chars: int = 4000) -> str` (pure) and `fetch_text(url: str, max_chars: int = 4000) -> str` (network; returns `""` on any failure).

- [ ] **Step 1: Write the failing test** — `tests/test_fetch_content.py`

```python
from notion_weekly_digest import fetch_content


def test_extract_text_strips_scripts_and_collapses_whitespace():
    html = "<html><body><script>x()</script><p>Hello   world</p>\n<p>Bye</p></body></html>"
    text = fetch_content.extract_text(html)
    assert "x()" not in text
    assert "Hello world Bye" in text


def test_extract_text_truncates():
    html = "<p>" + ("a" * 100) + "</p>"
    assert len(fetch_content.extract_text(html, max_chars=10)) == 10


def test_fetch_text_returns_empty_on_error(monkeypatch):
    def boom(*args, **kwargs):
        raise RuntimeError("network down")

    monkeypatch.setattr(fetch_content.requests, "get", boom)
    assert fetch_content.fetch_text("https://example.com") == ""
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_fetch_content.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'notion_weekly_digest.fetch_content'`

- [ ] **Step 3: Write `notion_weekly_digest/fetch_content.py`**

```python
from __future__ import annotations

import requests
from bs4 import BeautifulSoup


def extract_text(html: str, max_chars: int = 4000) -> str:
    soup = BeautifulSoup(html, "html.parser")
    for tag in soup(["script", "style", "nav", "header", "footer"]):
        tag.decompose()
    text = " ".join(soup.get_text(separator=" ").split())
    return text[:max_chars]


def fetch_text(url: str, max_chars: int = 4000) -> str:
    try:
        resp = requests.get(
            url, timeout=20, headers={"User-Agent": "notion-weekly-digest/1.0"}
        )
        resp.raise_for_status()
        return extract_text(resp.text, max_chars)
    except Exception:
        return ""
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_fetch_content.py -v`
Expected: PASS (3 passed)

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: article body text extraction"
```

---

### Task 7: Rendering

**Files:**
- Create: `notion_weekly_digest/render.py`
- Test: `tests/test_render.py`

**Interfaces:**
- Consumes: `Summary`.
- Produces: `render_article(s: Summary) -> str` and `render_digest(summaries: list[Summary], week_label: str) -> str`. Output uses literal tabs for nesting per Global Constraints.

- [ ] **Step 1: Write the failing test** — `tests/test_render.py`

```python
from notion_weekly_digest.models import Summary
from notion_weekly_digest.render import render_article, render_digest


def test_render_article_exact_format():
    s = Summary(
        title="Cool Post",
        url="https://e.com/p",
        source="Hacker News",
        one_liner="한 줄 요약",
        detail="핵심 두세 문장.",
        extra=["참고: https://e.com/ref"],
    )
    assert render_article(s) == (
        "- [Cool Post](https://e.com/p)\n"
        "\t- 한 줄 요약\n"
        "\t- 핵심 두세 문장.\n"
        "\t- 참고: https://e.com/ref"
    )


def test_render_digest_has_heading_and_divider():
    s = Summary("T", "u", "GeekNews", "o", "d")
    out = render_digest([s], "2026-W27 (06.29~07.05)")
    assert out.startswith("## 2026-W27 (06.29~07.05)")
    assert out.rstrip().endswith("---")
    assert "- [T](u)" in out
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_render.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'notion_weekly_digest.render'`

- [ ] **Step 3: Write `notion_weekly_digest/render.py`**

```python
from __future__ import annotations

from .models import Summary


def render_article(s: Summary) -> str:
    lines = [f"- [{s.title}]({s.url})", f"\t- {s.one_liner}", f"\t- {s.detail}"]
    lines.extend(f"\t- {x}" for x in s.extra)
    return "\n".join(lines)


def render_digest(summaries: list[Summary], week_label: str) -> str:
    parts = [f"## {week_label}", ""]
    for s in summaries:
        parts.append(render_article(s))
        parts.append("")
    parts.append("---")
    return "\n".join(parts).rstrip() + "\n"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_render.py -v`
Expected: PASS (2 passed)

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: Notion bullet markdown renderer"
```

---

### Task 8: Summarize via codex

**Files:**
- Create: `notion_weekly_digest/summarize.py`
- Test: `tests/test_summarize.py`

**Interfaces:**
- Consumes: `Article`, `Summary`.
- Produces:
  - `build_prompt(items: list[tuple[Article, str]], target_count: int) -> str`
  - `run_codex(prompt: str, timeout: int = 300) -> str` (subprocess; the real codex call)
  - `extract_block(output: str) -> str` (slice between sentinels)
  - `parse_block(block: str) -> list[Summary]`
  - `summarize(items, target_count: int = 6, runner=run_codex) -> list[Summary]` — `runner` is injectable so tests never invoke codex. Fills each `Summary.source` by matching its URL back to `items`.
- Module constants `START = "===DIGEST START==="`, `END = "===DIGEST END==="`.

- [ ] **Step 1: Empirically verify codex exec before wiring it**

Run: `codex exec "한 단어로만 답하세요: 사과의 색은?"`
Expected: prints a short model answer to stdout (e.g. "빨강"). Note whether there is surrounding log noise — the sentinel slicing in `extract_block` is what makes parsing robust to it. If `codex exec` errors about sandbox/approval in this non-interactive context, capture the exact flag it suggests and add it to the `run_codex` arg list (e.g. an auto-approve flag); the parsing/prompt design is unaffected.

- [ ] **Step 2: Write the failing test** — `tests/test_summarize.py`

```python
from notion_weekly_digest.models import Article
from notion_weekly_digest import summarize as S


def test_build_prompt_includes_sentinels_and_candidates():
    items = [(Article("T1", "https://e.com/1", "GeekNews", 10, 2), "본문 발췌")]
    p = S.build_prompt(items, target_count=1)
    assert S.START in p and S.END in p
    assert "T1" in p and "https://e.com/1" in p


def test_extract_block_slices_between_sentinels():
    out = f"log line\n{S.START}\n- [A](u)\n{S.END}\ntrailing"
    assert S.extract_block(out).strip() == "- [A](u)"


def test_extract_block_raises_without_sentinels():
    import pytest

    with pytest.raises(ValueError):
        S.extract_block("no markers here")


def test_parse_block_builds_summaries():
    block = (
        "- [Title One](https://e.com/1)\n"
        "\t- 한 줄\n"
        "\t- 두세 문장.\n"
        "\t- 참고 포인트\n"
        "- [Title Two](https://e.com/2)\n"
        "\t- 한 줄2\n"
        "\t- 본문2\n"
    )
    out = S.parse_block(block)
    assert len(out) == 2
    assert out[0].title == "Title One"
    assert out[0].url == "https://e.com/1"
    assert out[0].one_liner == "한 줄"
    assert out[0].detail == "두세 문장."
    assert out[0].extra == ["참고 포인트"]
    assert out[1].extra == []


def test_summarize_uses_injected_runner_and_fills_source():
    items = [(Article("Title One", "https://e.com/1", "GeekNews", 5, 1), "본문")]
    canned = f"{S.START}\n- [Title One](https://e.com/1)\n\t- 한 줄\n\t- 문장.\n{S.END}"
    out = S.summarize(items, target_count=1, runner=lambda prompt: canned)
    assert len(out) == 1
    assert out[0].source == "GeekNews"
```

- [ ] **Step 3: Run test to verify it fails**

Run: `pytest tests/test_summarize.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'notion_weekly_digest.summarize'`

- [ ] **Step 4: Write `notion_weekly_digest/summarize.py`**

```python
from __future__ import annotations

import re
import subprocess

from .models import Article, Summary

START = "===DIGEST START==="
END = "===DIGEST END==="

_LINK_RE = re.compile(r"^- \[(.+?)\]\((.+?)\)\s*$")
_SUB_RE = re.compile(r"^\t- (.*)$")


def build_prompt(items: list[tuple[Article, str]], target_count: int) -> str:
    blocks = []
    for i, (a, text) in enumerate(items, 1):
        blocks.append(
            f"[{i}] 제목: {a.title}\n"
            f"URL: {a.url}\n"
            f"출처: {a.source}\n"
            f"포인트: {a.points} 댓글: {a.comments}\n"
            f"본문발췌: {text}\n"
        )
    joined = "\n".join(blocks)
    return (
        f"당신은 개발 뉴스 큐레이터입니다. 아래 후보 글 중 가장 가치 있는 "
        f"{target_count}개를 골라 한국어로 요약하세요. 반드시 마커 사이에만, "
        f"아래 형식 그대로 출력하세요. 들여쓰기는 탭 한 개를 쓰세요.\n\n"
        f"형식 (글 1개당):\n"
        f"- [원문제목](원문URL)\n"
        f"\t- 한 줄 요약 (이게 뭔지)\n"
        f"\t- 핵심 내용 2~3문장\n"
        f"\t- (선택) 핵심 takeaway 또는 추가 참고 포인트\n\n"
        f"{START}\n"
        f"(여기에 선택한 {target_count}개를 위 형식으로)\n"
        f"{END}\n\n"
        f"후보 목록:\n{joined}\n"
    )


def run_codex(prompt: str, timeout: int = 300) -> str:
    proc = subprocess.run(
        ["codex", "exec", prompt],
        capture_output=True,
        text=True,
        timeout=timeout,
    )
    if proc.returncode != 0:
        raise RuntimeError(
            f"codex exec failed (rc={proc.returncode}): {proc.stderr[:500]}"
        )
    return proc.stdout


def extract_block(output: str) -> str:
    if START not in output or END not in output:
        raise ValueError("codex output missing sentinels")
    return output.split(START, 1)[1].split(END, 1)[0].strip()


def parse_block(block: str) -> list[Summary]:
    summaries: list[Summary] = []
    cur: Summary | None = None
    subs: list[str] = []

    def flush() -> None:
        nonlocal cur, subs
        if cur is not None:
            cur.one_liner = subs[0] if len(subs) > 0 else ""
            cur.detail = subs[1] if len(subs) > 1 else ""
            cur.extra = subs[2:] if len(subs) > 2 else []
            summaries.append(cur)
        cur = None
        subs = []

    for line in block.splitlines():
        m = _LINK_RE.match(line)
        if m:
            flush()
            cur = Summary(
                title=m.group(1), url=m.group(2), source="", one_liner="", detail=""
            )
            continue
        sm = _SUB_RE.match(line)
        if sm and cur is not None:
            subs.append(sm.group(1).strip())
    flush()
    return summaries


def summarize(
    items: list[tuple[Article, str]], target_count: int = 6, runner=run_codex
) -> list[Summary]:
    prompt = build_prompt(items, target_count)
    output = runner(prompt)
    block = extract_block(output)
    summaries = parse_block(block)
    source_by_url = {a.url: a.source for a, _ in items}
    for s in summaries:
        s.source = source_by_url.get(s.url, "")
    return summaries
```

- [ ] **Step 5: Run test to verify it passes**

Run: `pytest tests/test_summarize.py -v`
Expected: PASS (5 passed)

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: codex-based selection + Korean summarization"
```

---

### Task 9: Orchestration (run.py)

**Files:**
- Create: `notion_weekly_digest/run.py`
- Test: `tests/test_run.py`

**Interfaces:**
- Consumes: `geeknews.fetch`, `hackernews.fetch`, `rank_candidates`, `filter_unseen`, `mark_seen`, `fetch_text`, `summarize`, `render_digest`.
- Produces: `week_label(now: datetime) -> str`, `collect() -> list[Article]`, `main(now=None, target_count: int = 6, state_path=STATE_PATH, output_dir=OUTPUT_DIR) -> str` (returns output file path). Module constants `STATE_PATH = "state/seen.json"`, `OUTPUT_DIR = "output"`.

- [ ] **Step 1: Write the failing test** — `tests/test_run.py`

```python
from datetime import datetime, timezone

from notion_weekly_digest.models import Article, Summary
from notion_weekly_digest import run


def test_week_label_format():
    label = run.week_label(datetime(2026, 6, 29, tzinfo=timezone.utc))
    assert label.startswith("2026-W27")
    assert "06.29" in label


def test_main_writes_digest_and_marks_seen(tmp_path, monkeypatch):
    monkeypatch.setattr(
        run.geeknews, "fetch",
        lambda *a, **k: [Article("G", "https://e.com/g", "GeekNews", 0, 0)],
    )
    monkeypatch.setattr(
        run.hackernews, "fetch",
        lambda *a, **k: [Article("H", "https://e.com/h", "Hacker News", 99, 9)],
    )
    monkeypatch.setattr(run, "fetch_text", lambda url, **k: "body")
    monkeypatch.setattr(
        run, "summarize",
        lambda items, target_count=6: [
            Summary("H", "https://e.com/h", "Hacker News", "한줄", "문장.")
        ],
    )
    state_path = str(tmp_path / "seen.json")
    out_dir = str(tmp_path / "out")
    path = run.main(
        now=datetime(2026, 6, 29, tzinfo=timezone.utc),
        state_path=state_path, output_dir=out_dir,
    )
    content = open(path, encoding="utf-8").read()
    assert "- [H](https://e.com/h)" in content
    from notion_weekly_digest.state import load_seen
    assert "https://e.com/h" in load_seen(state_path)


def test_collect_survives_one_failing_source(monkeypatch):
    monkeypatch.setattr(
        run.geeknews, "fetch",
        lambda *a, **k: (_ for _ in ()).throw(RuntimeError("down")),
    )
    monkeypatch.setattr(
        run.hackernews, "fetch",
        lambda *a, **k: [Article("H", "u", "Hacker News", 1, 1)],
    )
    arts = run.collect()
    assert [a.url for a in arts] == ["u"]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_run.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'notion_weekly_digest.run'`

- [ ] **Step 3: Write `notion_weekly_digest/run.py`**

```python
from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone

from .models import Article
from .sources import geeknews, hackernews
from .rank import rank_candidates
from .state import filter_unseen, mark_seen
from .fetch_content import fetch_text
from .summarize import summarize
from .render import render_digest

STATE_PATH = "state/seen.json"
OUTPUT_DIR = "output"


def week_label(now: datetime) -> str:
    iso = now.isocalendar()
    start = now - timedelta(days=now.weekday())
    end = start + timedelta(days=6)
    return f"{iso.year}-W{iso.week:02d} ({start:%m.%d}~{end:%m.%d})"


def collect() -> list[Article]:
    articles: list[Article] = []
    for src in (geeknews, hackernews):
        try:
            articles.extend(src.fetch())
        except Exception as e:  # noqa: BLE001 - one bad source must not abort
            print(f"[warn] source {src.__name__} failed: {e}")
    if not articles:
        raise RuntimeError("all sources failed")
    return articles


def main(
    now: datetime | None = None,
    target_count: int = 6,
    state_path: str = STATE_PATH,
    output_dir: str = OUTPUT_DIR,
) -> str:
    now = now or datetime.now(timezone.utc)
    articles = collect()
    candidates = rank_candidates(articles)
    fresh = filter_unseen(state_path, candidates)
    items = [(a, fetch_text(a.url)) for a in fresh]
    summaries = summarize(items, target_count=target_count)
    if not summaries:
        raise RuntimeError("summarize returned nothing; aborting (no partial write)")
    md = render_digest(summaries, week_label(now))
    os.makedirs(output_dir, exist_ok=True)
    out_path = os.path.join(output_dir, f"digest-{now:%Y-%m-%d}.md")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(md)
    mark_seen(state_path, [s.url for s in summaries])
    print(out_path)
    print(md)
    return out_path


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_run.py -v`
Expected: PASS (3 passed)

- [ ] **Step 5: Run the full suite**

Run: `pytest -v`
Expected: PASS (all tests across tasks 1–9)

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: pipeline orchestration (run.py)"
```

---

### Task 10: Runbook + app docs

**Files:**
- Create/Modify: `README.md`, `CLAUDE.md`
- Modify (root repo): `brain/apps.md` (status row — only if not already added by `new-app`)

**Interfaces:** none (documentation).

- [ ] **Step 1: Write `README.md`**

````markdown
# notion-weekly-digest

매주 수동 실행으로 GeekNews + Hacker News의 개발 뉴스를 수집·선별하고,
로컬 GPT-5.5(`codex`)로 한국어 요약해서 Notion 레퍼런스 아티클 양식의
마크다운을 생성한다. 생성된 마크다운은 Claude가 Notion MCP로 Joh's Notion
스테이징 페이지에 게시한다.

## Setup

```bash
pip install -e ".[dev]"
```

`codex` CLI가 설치돼 있고 ChatGPT 계정으로 로그인돼 있어야 한다(요약 엔진).

## 주간 실행 절차

1. 파이프라인 실행 — 수집·랭킹·요약 후 `output/digest-YYYY-MM-DD.md` 생성:

   ```bash
   python -m notion_weekly_digest.run
   ```

2. Claude에게 게시 요청 — "이번주 다이제스트 노션에 올려줘". Claude가
   `output/digest-*.md`를 읽어 Notion MCP(`notion-update-page`)로 스테이징
   페이지에 주차 섹션을 추가한다.

3. 사용자가 Notion 스테이징 페이지에서 검토 → Aisle 워크스페이스로 복사.

## 동작 메모

- 같은 글을 다음 주에 다시 요약하지 않도록 `state/seen.json`에 게시한 URL을 기록한다.
- 한 소스가 실패해도 다른 소스로 진행한다. 둘 다 실패하면 중단한다.
- 요약은 codex 출력의 `===DIGEST START===`/`===DIGEST END===` 사이만 파싱한다.
````

- [ ] **Step 2: Write app `CLAUDE.md`** (operational contract for Claude)

````markdown
# notion-weekly-digest

매주 개발 뉴스를 요약해 Notion 레퍼런스 아티클로 게시하는 앱.

## 게시 단계는 Claude가 한다 (스크립트 아님)

`python -m notion_weekly_digest.run` 이 `output/digest-*.md`를 만들면,
그 내용을 읽어 **Notion MCP**로 스테이징 페이지에 append 한다:

- 도구: `notion-fetch`(현재 내용 확인) → `notion-update-page`(주차 섹션 추가)
- 스테이징 페이지: Joh's Notion (개인 워크스페이스). 페이지 ID는 최초 1회 확정 후 여기 기록.
- 같은 주차 섹션이 이미 있으면 중복 추가하지 말고 사용자에게 확인.
- Aisle 워크스페이스는 API가 막혀 있어 직접 못 쓴다 — 사용자가 수동 복사한다.

## 요약 엔진

로컬 `codex exec`(GPT-5.5, ChatGPT 구독 auth). API 키 없음.
````

- [ ] **Step 3: Confirm app is registered in `brain/apps.md`**

If `new-app` already added a row, verify it reads:
`| notion-weekly-digest | weekly dev-news digest → Notion reference articles | Python | active |`
If absent, add that row (root repo). Commit in the **root** repo separately from the app repo.

- [ ] **Step 4: Commit (app repo)**

```bash
git add -A
git commit -m "docs: README + Claude runbook for Notion posting"
```

---

## Self-Review

**1. Spec coverage** (spec = `overview.md`):
- Sources GeekNews + HN → Tasks 2, 3. ✓
- 인기순 후보 → GPT 선별 → Task 4 (rank) + Task 8 (codex select/summarize). ✓
- codex(GPT-5.5) 요약, 본문은 스크립트가 fetch → Task 6 + Task 8 (`build_prompt` takes fetched text). ✓
- 한국어 요약 → prompt in Task 8 (Korean). ✓
- 출력 양식(불릿+중첩) → Task 7 render, asserted exactly. ✓
- 주차 간 중복 방지(seen.json) → Task 5 + wired in Task 9. ✓
- 게시 = 옵션 1 (Claude MCP) → Task 10 runbook (not script code). ✓
- 멱등성/에러 처리(소스 일부 실패, 부분 게시 금지) → Task 9 `collect` + `main` guard, tested. ✓
- 앱 위치/스택 → Task 1. ✓
- Open items (스테이징 페이지 ID, GeekNews 점수 노출, 주당 개수) → deferred: page ID recorded in Task 10 CLAUDE.md at first run; GeekNews points handled best-effort in Task 2 + verified in Task 2 Step 1; per-week count defaults to 6 (`target_count`). ✓

**2. Placeholder scan:** No "TBD/TODO/handle edge cases" in steps; all code and test bodies are complete. The two intentional runtime-verification steps (Task 2 Step 1 curl, Task 8 Step 1 codex check) carry concrete commands and fallbacks, not placeholders. ✓

**3. Type consistency:** `Article`/`Summary` fields identical across tasks. `rank_candidates(per_source=)`, `filter_unseen(path, articles)`, `mark_seen(path, urls)`, `fetch_text(url)`, `summarize(items, target_count, runner)`, `render_digest(summaries, week_label)` — signatures used in `run.py` (Task 9) match their definitions. `START`/`END` sentinels shared between `summarize.py` and its tests. ✓
