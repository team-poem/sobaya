# Complete code and design rationale

Use this reference when preparing the human review view required by the TDD
skill. The output presents the entire original source once, followed by Korean
rationale outside the code. It is a presentation artifact, not an executable
plan, approval record, or test runner input.

## Source inventory

Before generating views, list every proposed test body, executable section
header, and required helper/fixture, with its destination and dependent plan
entries. Include code and data that determine expectations even when shared or
stored outside `failed-test.md`. Show each complete source unit continuously;
preserve its source comments, whitespace, order, and line endings. Copy plan
blocks without their surrounding Markdown fences. Keep separate original units
separate rather than silently manufacturing a combined source with new spacing.

Explain shared support once and link to that view and its relevant line ranges
from every dependent entry. The inventory must account for all required units;
the generator only knows the one source supplied to it and cannot discover an
entire omitted header, helper, fixture, or test.

## Rationale for every range

Partition every source unit into ordered, contiguous ranges of physical lines.
The first starts at 1, each next range starts immediately after the previous
one ends, and the last ends at the final line. A final unterminated line counts
as a line. Assign blank lines and closing delimiters to a neighboring range;
no gaps, overlaps, or omissions based on importance are allowed.

Choose ranges that make the design choices readable. Setup/action/assertion
grouping is optional. A range may span multiple lines, but its explanation must
account for each choice within them; a generic paragraph for a whole test does
not satisfy that requirement. For each range write these four fields in Korean:

| Field | Content |
|---|---|
| `what` | What the code or data does, including relevant control flow. |
| `why` | Why this setup, action, assertion, or support was chosen for this test. |
| `basis` | The basis of the values, conditions, mocks, and expectations: cite the requirement when known; label examples or arbitrary choices, assumptions, and unresolved expectations distinctly. |
| `relates_to` | How the range contributes to the test's evidence, references to shared support when used, and what it does not establish. |

Do not invent a requirement or a design history to fill a field. State when a
choice has no established basis and needs human judgment. Explain what mocks,
fixtures, clocks, and helpers assume or bypass. Keep claims within the actual
assertions: checking a response status is not evidence of a visible UI message.

## Generate the review document

Save an exact source unit and a separate JSON notes file, then run from the
Sobaya root. The helper uses Bash 3.2, jq, and standard Unix tools including
`iconv` and POSIX `link`; the destination filesystem must support hard links:

```sh
shasum -a 256 /tmp/review-source.js
tdd-set/bin/review-view.sh /tmp/review-source.js /tmp/review-notes.json /tmp/review.md
```

Use the reported source hash in the notes. The output path must be new; the
helper creates Markdown without modifying the source, notes, plan, tests, or
approval baseline. Repeat for other inventory items and explicitly connect
shared views to their dependent entries in the review document or conversation.

The version-1 notes object has this shape. This example assumes a three-line
source; replace the illustrative hash and all descriptions with the actual
source's hash and rationale:

```json
{
  "review_version": 1,
  "source_sha256": "0000000000000000000000000000000000000000000000000000000000000000",
  "target": "add.test.js",
  "entry": "addAdds",
  "language": "js",
  "regions": [
    {
      "start": 1,
      "end": 1,
      "what": "테스트를 등록한다.",
      "why": "플랜의 addAdds 항목을 실행 결과에서 식별한다.",
      "basis": "이름은 플랜 항목과 연결하기 위한 식별자이며 동작 요구사항은 아니다.",
      "relates_to": "review-header.md의 2~4줄에서 불러온 도구와 add 함수를 사용하며 선언만으로 성공을 증명하지 않는다."
    },
    {
      "start": 2,
      "end": 3,
      "what": "add(1, 2)의 반환값을 숫자 3과 엄격하게 비교하고 테스트를 닫는다.",
      "why": "두 양수를 더하는 기본 예시의 결과를 형 변환 없이 검증한다.",
      "basis": "1과 2는 템플릿의 예시 입력이며 필수 경계값은 아니다. 3은 두 값의 산술 합이다.",
      "relates_to": "이 입력의 반환값만 증명하며 음수, 빈 입력, 오버플로는 확인하지 않는다."
    }
  ]
}
```

`review_version` is the number `1`. `source_sha256` is a 64-digit lowercase hexadecimal
SHA-256 digest of the exact source bytes. `target`, `entry`, and `language` are
nonblank single-line strings identifying the destination, plan entry (or shared
support), and code-fence language. `language` matches `^[A-Za-z0-9_+-]+$`; use
`text` for plain text. Each region has integer `start`/`end` and nonblank
single-line `what`, `why`, `basis`, and `relates_to` strings. Metadata and rationale
strings must not contain control characters. They render as plain text; put
clickable links to shared views in the enclosing document or conversation. Line
numbers refer to the original source, not the rendered Markdown.

The helper checks the hash, notes structure, and exact sequential line coverage,
then renders the entire source once and the range rationale after it. It
accepts nonempty UTF-8 source without NUL bytes and preserves LF/CRLF source
bytes. Bare CR line endings are rejected to prevent a mismatch between code
lines and the rationale ranges; do not silently normalize the source. Notes
must also be UTF-8 without raw NUL bytes. When the source has no final newline, the
Markdown fence needs a separator newline; the document records that separator
and the original byte count/hash so it is not mistaken for an input change;
the original byte count inside the fence recovers the original source.
The document also reports the line count and final-newline state. The output
path must not already exist, including as a symlink. Invalid input produces no
output artifact. The JSON receipt on stdout has `review_only: true` and records
structural checks only.
No code formatting, comment insertion, or comment removal occurs.

Before presenting the result, compare it with the source inventory and read
every explanation against the actual code and specification. Structural checks
cannot prove that a rationale is true, sufficiently specific, or complete in
meaning. Resolve unsupported claims and surface uncertain expectations for the
human. A successful generator run does not constitute approval.

## Revisions and approval

Deliver the view in conversation or a separate document, keeping review prose
and duplicate executable fences out of `failed-test.md`. Approval covers the
exact executable inputs shown. Probes and the runtime consume those originals;
there is no stripping or reformatting step after review.

For revisions or replacements, state the reason and changed expectations, then
repeat the full source inventory and complete code/rationale view. Do not show
only a diff or only changed assertions. Reused shared views must still match
their source and be explicitly referenced. Preserve the approved plan, tests,
headers, helpers, and fixtures until the human approves the changed inputs and
replacement baseline. Changed source needs a fresh hash and reviewed rationale;
updating the hash alone does not update the review.
