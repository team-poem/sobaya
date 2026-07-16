# Apps

One line per app. `new-app` registers entries; keep status current
(scaffolded → active → paused → archived · imported = external/vendor
source dropped into `apps/`, not sobaya-scaffolded).

Apps are per-clone and never pushed to this repo — sobaya is a
harness-only template; each checkout grows its own `apps/`. Whether an
app keeps a local repo or a remote is the app's own choice, so "local
only" below is a fact, not a problem. Only flag a Git cell when a
clone's origin still points at this template repo (push hazard).

| App | Purpose | Stack | Status | Git |
|---|---|---|---|---|
| soba-timer | noodle-cooking countdown timer | Go | active | own repo (local only) |
| desk-room-3d | interactive 3D desk scene for blog main page | React/R3F/Vite | active | own repo (local only) |
| lms-chatbot-model-change | LearningX LMS RAG chatbot fork for model/purpose changes | Python/FastAPI/Ollama | active | team-poem/lms-chatbot |
| notion-weekly-digest | weekly dev-news digest → Notion reference articles | Python | active | own repo (local only) |
| office-automation-hub-design | FDE office-automation hub — specs at top level, app nested at `app/` (plans 05/06) | Python + static UI | active | ⚠ nested repo at `app/.git` — predates flat-root rule, flatten when branch work settles |
| bdad-mentor-match | BDAD mentor-matching workspace — full sobaya harness clone (apps/brain/CLAUDE.md inside) | sobaya clone | active | ⚠ origin = this template repo (repoint/remove before push); nested workspace also breaks the flat-root rule |
| bdad-report | BDAD learning-community activity report generation (xlsx/pdf in, scripts out) | Python scripts | active | ⚠ no git repo yet — init before next work |
| DsuGroupware2-Source | Dongseo groupware v2 vendor source drop | C#/installer | imported | GP101/DsuGroupware2-Source |
| employee-feedback-form | employee feedback form web app | Next.js | active | amazon7737/work-helper |
| FOX | 대학혁신지원사업 성과관리 시스템 (Dongseo Univ.) | Next.js | active | nugurik/FOX |
| gdsu-rule-crawler | university internal-rules crawler + RAG bot | Node/Go/Docker | active | team-poem/dsu-rule-bot |
| gyowon-eval-aggregation | faculty evaluation score aggregation script | Python | paused | ⚠ no git repo yet — init before next work |
| kordoc-hwp-markdown | HWP → markdown conversion pipeline (report bot) | Docker | active | team-poem/report-bot |
| mydex-app-pg-poc | MYDEX JSP app PostgreSQL port PoC | JSP | imported | ⚠ no git repo (imported drop) |
| mydex-oracle-dump | MYDEX Oracle full dump + migration shell scripts | shell/Oracle | active | amazon7737/mydex-oracle-migration-shell |
| mydex-was | MYDEX WAS runtime inspection scripts and notes | PowerShell | imported | ⚠ no git repo (imported drop) |
| mydex2.0 | MYDEX 2.0 rebuild | Next.js/Docker | active | nugurik/mydex2.0 |
| pi-test-05-08 | pi harness experiment (noodle clone + 상담예약 test site) | mixed | paused | ⚠ no git repo yet — init before next work |
| cairn-desktop | watchable Chrome driven by cairn over CDP + agent HTTP API | Tauri 2/Rust/TS | active | own repo (local only) |
| ubireport-jsp-sample | UbiReport JSP sample vendor drop | JSP | imported | ⚠ no git repo (vendor drop) |
| ubireport-server | UbiReport server binaries + manuals vendor drop | binary | imported | ⚠ no git repo (vendor drop) |
