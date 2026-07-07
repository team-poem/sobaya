# Driving Chrome over CDP — gotchas that cost turns

Learned building cairn-desktop (plan 12); they apply to any app or test
harness in this workspace that talks to Chrome directly.

**`/json/new` no longer navigates.** On current Chrome (v151-era), `PUT
/json/new?url=…` creates the tab but leaves it at `about:blank` — the url
param is ignored. Navigation must go through the CDP websocket
(`Page.navigate`). A helper lives at the session scratchpad pattern
`navigate.mjs` (fetch `/json/list` → connect page ws → `Page.navigate`);
cairn-desktop's contract fixtures assume this, and cairn itself navigates
via chrome-devtools-mcp, which is unaffected.

**`--headless=new` composites only the visible tab.** A page created in
the background attaches fine and even reports screencast visibility, but
emits zero `Page.screencastFrame`s until `Page.bringToFront`. Any
screencast/screenshot pipeline must bring the target page to front first
(cairn-desktop does this in `cdp/mirror.rs`).

**Holding the client keeps the event channel alive — liveness needs an
out-of-band signal.** Pattern: a tokio broadcast channel closes only when
all senders drop; if a consumer loop holds an `Arc` of the client that
owns the sender, `recv()` never errors on socket death and the loop hangs
forever — "detect close by awaiting the channel" silently becomes dead
code. cairn-desktop hit exactly this (`run_mirror` never returned when
Chrome died) and fixed it by exposing `CdpClient::is_closed()` and racing
the loop against a close-poll. General rule: when you hold the resource
that keeps a channel open, closure detection must come from a separate
signal, not the channel itself. [[principles/prove-it-works]] — the
degraded path looked implemented but was unreachable until a real kill
test ran.
