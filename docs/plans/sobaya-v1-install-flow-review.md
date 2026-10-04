# Sobaya v1 설치·모드 연결·bump 테스트 검토본

검토용 — 설명 주석은 실행 코드에 포함되지 않음

2026-10-04 요청에 따라 배포 묶음 다음 세 단계의 테스트를 한 번에 준비했습니다.
아래 실행용 테스트와 공통 준비 코드는 **아직 승인 전**입니다. 기존 설정·배포
테스트와 실행기 구현은 그대로 유지했습니다. PR #6은 병합됐고 PR #7은 아직
열려 있으므로, 이 후속 작업은 PR #7의 검증된 커밋에서 이어집니다.

## 사용할 흐름

1. 출처를 확인한 매니페스트로 버전별 실행기를 프로젝트 밖에 설치합니다.
2. `init`으로 프로젝트 또는 종속 모드를 명시하고 기존 지침·훅에 연결합니다.
3. 고정한 실행기로 기존 승인·TDD·검증 사이클을 돌립니다.
4. `bump`가 새 실행기로 전체 검사를 통과시키면 설정·lock 변경만 남깁니다.

### 최초 설치

```sh
bash /trusted/install-runtime.sh \
  --root /path/to/consumer --install-root /path/to/sobaya-store \
  --version 1.0.0-rc.1 --manifest /trusted/sobaya-1.0.0-rc.1.json \
  --archive /path/to/sobaya-1.0.0-rc.1.tar.gz
```

`--archive`를 생략하면 해당 버전의 `team-poem/sobaya` GitHub Release에서
압축 파일을 내려받습니다. `--manifest`는 사용자가 출처를 확인한 로컬 파일입니다.
매니페스트에 적힌 임의 URL을 실행하거나 원격 매니페스트를 자동 신뢰하지 않습니다.
처음 실행하는 설치 스크립트 자체도 고정된 소스에서 별도로 확인해야 합니다.
SHA-256과 압축 내부 커밋 표시는 파일 일치 검사이며 독립적인 서명 인증은 아닙니다.

설치 위치는 `STORE/runtimes/VERSION/runtime`입니다. 원본 압축과 매니페스트도
버전 폴더에 남기며, `STORE/bin/sobaya`가 공통 명령 진입점이 됩니다. 같은 버전의
정상 설치를 반복하면 변하지 않습니다. 다른 커밋·해시로 같은 버전을 덮어쓰거나
손상된 설치를 조용히 복구하지 않습니다. 실패한 새 설치가 기존 버전을 훼손하면 안 됩니다.

### 모드 연결과 실행

```sh
sobaya init --root /consumer --install-root /store --mode dependency --version 1.0.0-rc.1
sobaya init --root /workspace --install-root /store --mode project --version 1.0.0-rc.1 --app /workspace/apps/example
sobaya doctor --root /consumer --install-root /store --policy /path/to/policy.json
sobaya approve --root /consumer --install-root /store
sobaya loop --root /consumer --install-root /store --policy /path/to/policy.json
```

프로젝트 모드의 앱 명령에는 `--app`을 붙입니다. 기존 `AGENTS.md`, `spec.md`,
테스트 계획을 바꾸지 않고, 승인·호출 수·진행 상태는 기존 앱 Git 메타데이터에
유지합니다. `init`이 테스트를 승인하지 않습니다. 사람의 실제 승인 없이 위
`approve` 명령을 실행하라는 뜻도 아닙니다.

종속 모드에서는 소비 프로젝트의 기존 모노레포 `apps/`도 보존합니다. 프로젝트
모드는 기존 `apps/`와 `brain/`을 유지하며 여러 앱을 같은 작업 공간에 연결할 수
있습니다. 개인 설치 경로는 공유 설정·lock에 넣지 않습니다.

기존 `pre-commit`을 먼저 실행하고 성공했을 때 소바야 검사를 실행합니다.
기존 훅 파일과 심링크는 보존하고 로컬 Git 연결 설정으로 이어 붙입니다.
검토 코드에는 `commit-msg`의 인자 전달과 실제 커밋 차단도 포함됩니다.
연결 워크트리 사례는 Git의 `extensions.worktreeConfig`가 이미 켜져 있는
상태에서 다른 워크트리와 공유 설정을 보존하는지 검사합니다. 복잡한 기존 Git
설정의 자동 이관이나 모든 서버용 훅 프로토콜을 이 테스트로 검증했다고 보지 않습니다.

### 고정 설치 복원과 버전 변경

```sh
sobaya sync --root /consumer --install-root /store --archive /path/to/locked-version.tar.gz
sobaya bump --root /consumer --install-root /store --version 1.0.0-rc.2 \
  --manifest /trusted/sobaya-1.0.0-rc.2.json --archive /path/to/candidate.tar.gz
```

`sync`는 기존 lock을 바꾸지 않고 그 버전을 설치합니다. `bump`는 후보 실행기로
전체 테스트와 위생 검사를 돌립니다. 프로젝트 모드에서는 연결한 앱을 모두 검사합니다.
성공하면 `sobaya.json`과 `sobaya.lock` 변경만 남겨 PR로 검토할 수 있게 합니다.
커밋·푸시·테스트 재승인을 자동으로 수행하지 않습니다. 검사 실패 시 두 파일의
이전 바이트를 복구하고, 진행 중인 항목이 있으면 변경을 거절합니다.

## 검토할 12개 항목

| 순서 | 기대 동작 |
|---|---|
| 1 | 실제 배포 파일의 내용·실행 권한·커밋·해시를 설치하고, 로컬 파일과 다운로드가 같은 검증을 사용 |
| 2 | 잘못된 메타데이터·다중 JSON·해시·커밋과 필수 파일 누락, 링크·중복·특수 파일·경로 이탈을 거절 |
| 3 | 기존 경로·다른 버전·심링크 대상 보존, 부분 다운로드 실패·동일 버전 재지정·설치 손상 거절 |
| 4 | 두 모드 연결과 재실행이 지침·명세·계획·기존 디렉터리를 보존하고 승인을 만들지 않음 |
| 5 | 기존 훅 → 소바야 lint 순서를 실제 커밋으로 확인하고 원래 훅과 인자를 보존 |
| 6 | 연결 워크트리의 훅 설정이 주 체크아웃과 공유 설정을 바꾸지 않음 |
| 7 | 두 모드에서 진단 → 승인 → 실제 RED/GREEN → 전체 게이트 → 독립 리뷰 기록까지 실행 |
| 8 | 설치되지 않은 lock으로 다른 버전에 우회하지 않고, 작업자의 버전 설정 변조를 체크포인트 전에 거절 |
| 9 | `sync`가 기존 lock·소비 프로젝트를 보존하며 정확한 파일만 설치 |
| 10 | bump가 실제 후보 실행기로 검사하고 사용자 설정·승인·호출 수를 보존하며 두 설정 파일만 변경 |
| 11 | 테스트 또는 lint 실패 시 설정·lock·상태 복구, 진행 중인 항목의 bump 거절 |
| 12 | 프로젝트 bump가 연결한 두 앱을 각각 검사하고 두 번째 앱 실패도 되돌림 |

공통 준비 코드도 승인 대상입니다. 임시 저장소에 현재 소스를 복사하고 실제
패키저로 두 시험 버전을 만듭니다. 실제 스위트 함수는 호출 기록만 추가한 래퍼를
통해 그대로 실행합니다. 가짜 작업자는 구현 또는 읽기 전용 리뷰 응답만 제공하며
Git·Node·테스트 게이트를 대체하지 않습니다. 다운로드 대역은 파일 전달만
대체하고 해시·압축 검사·설치 과정은 실제 구현을 호출하도록 설계했습니다.

새 설치 명령이 없으므로 현재 기능 결과는 `NOT PROBED`입니다. 테스트 초안의
문법·준비 코드·대조 실험과 실제 기능의 RED/GREEN은 구분합니다. 실제 GitHub
릴리스 다운로드, 서명 인증, 강제 종료·정전 시 두 파일의 원자적 교체, v0.9 왕복
호환성, 성능 동등성은 후속 출시 검증이 필요합니다. 아래 초안은 전체 스위트에
아직 등록하지 않았습니다.

## 전체 실행용 코드와 줄별 설명

실행용 원본은 `brain/plans/04-versioned-modes/draft-install-flow-tests.sh`이며,
승인 뒤 `tests/test-install-flow.sh`로 그대로 옮깁니다. 아래에서 `┎` 설명 줄만
제거하면 원문의 모든 바이트가 복원되어야 합니다.


원본 SHA-256: `b27ddd26f4d6e13f8a11d11d5df2cab5278547445082e5462de5797d580080c0`

````bash
#!/bin/bash
# DRAFT: installation, connection and bump inputs require human review.
# ┎ 실패한 명령과 설정되지 않은 변수 때문에 검증을 건너뛰고 계속 진행하지 않도록 합니다.
set -eu
# ┎ 파이프 앞부분이 실패해도 전체 작업이 성공한 것으로 처리되지 않도록 합니다.
set -o pipefail
# ┎ 실제 Git·Node 실행과 아카이브·해시·FIFO 준비에 필요한 도구를 확인하며, 없으면 행동 실패가 아닌 미검증으로 종료합니다.
for tool in git jq tar gzip shasum node mkfifo; do command -v "$tool" >/dev/null || { printf 'NOT PROBED: missing %s\n' "$tool" >&2; exit 2; }; done
# ┎ 이 초안 파일이 속한 Git 저장소의 루트를 찾아 실제 런타임과 배포 도구를 읽습니다.
ROOT=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
# ┎ 명시적으로 지정된 설치기를 우선 사용하고, 없으면 저장소의 예정된 설치기 경로를 사용합니다.
INSTALLER=${SOBAYA_INSTALLER:-"$ROOT/tdd-set/lib/install-runtime.sh"}
# ┎ 다른 작업 디렉터리에서 엉뚱한 설치기를 호출하지 않도록 절대 경로만 허용합니다.
case "$INSTALLER" in /*) ;; *) printf 'NOT PROBED: absolute installer required\n' >&2; exit 2 ;; esac
# ┎ 설치기가 아직 없으면 테스트 기대값의 RED로 간주하지 않고 실행 준비 부족으로 종료합니다.
[ -f "$INSTALLER" ] || { printf 'NOT PROBED: install-runtime.sh is absent\n' >&2; exit 2; }
# ┎ 자식 테스트에도 같은 설치기를 전달하고, 사용자 전역·시스템 Git 설정의 영향을 제외합니다.
export SOBAYA_INSTALLER="$INSTALLER" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
# ┎ 공통 실패 도우미는 이유와 마지막 명령의 오류 출력을 보여 준 뒤 현재 사례를 중단합니다.
fail() { printf 'FAIL: %s\n' "$*" >&2; [ ! -f "${WORK:-}/stderr" ] || cat "$WORK/stderr" >&2; exit 1; }
# ┎ 공통 비교 도우미는 두 파일의 바이트가 완전히 같아야 통과시킵니다.
same() { cmp -s "$1" "$2" || fail "changed or unequal: $1 / $2"; }
# ┎ 공통 포함 도우미는 정규식 해석 없이 지정한 문자열이 출력이나 파일에 존재하는지 확인합니다.
contains() { grep -Fq -- "$2" "$1" || fail "missing <$2> in $1"; }
# ┎ 공통 스냅샷 도우미는 경로·일반 파일 내용·권한·심볼릭 링크 대상을 비교 자료로 만듭니다. 소유자·시간·확장 속성은 비교하지 않습니다.
snapshot() {
  # ┎ 대상 디렉터리의 전체 경로와 일반 파일의 체크섬을 수집합니다. 링크 대상 파일의 내용은 이 줄에서 따라가 읽지 않습니다.
  (cd "$1"; find . -print; find . -type f -exec cksum {} \;
    # ┎ 특수 권한을 포함한 각 권한 비트의 보유 경로를 기록하여 내용 외의 권한 변경도 찾습니다.
    for mask in 4000 2000 1000 400 200 100 040 020 010 004 002 001; do find . ! -type l -perm "-$mask" -print | sed "s|^|mode:$mask |"; done
    # ┎ 심볼릭 링크 이름과 링크가 가리키는 문자열을 기록하여 링크 교체를 찾습니다.
    while IFS= read -r -d '' link; do printf '%s -> %s\n' "$link" "$(readlink "$link")"; done < <(find . -type l -print0)
  # ┎ 수집 순서의 차이가 변경으로 보이지 않도록 일정한 정렬 순서로 스냅샷을 저장합니다.
  ) | LC_ALL=C sort > "$2"
}
# ┎ 공통 실행 도우미는 명령의 표준 출력·오류를 따로 저장하고 종료 코드를 RC에 남겨 각 사례가 기대값을 판단하게 합니다.
invoke() { if "$@" > "$WORK/stdout" 2> "$WORK/stderr"; then RC=0; else RC=$?; fi; }
# ┎ 성공 기대 도우미는 마지막 명령의 종료 코드가 0인지 확인합니다.
okay() { [ "$RC" -eq 0 ] || fail "command exited $RC"; }
# ┎ 관리 명령의 잘못된 입력은 종료 코드 2, 빈 표준 출력, 지정한 오류 설명을 함께 요구합니다.
invalid() { [ "$RC" -eq 2 ] && [ ! -s "$WORK/stdout" ] || fail 'invalid management command must return 2 without stdout'; contains "$WORK/stderr" "$1"; }
# ┎ 공통 커밋 도우미는 준비용 파일을 커밋합니다. 이 도우미 자체는 훅 검증을 하지 않습니다.
commit_app() {
  # ┎ 준비한 앱 파일 전체를 실제 Git 인덱스에 올립니다.
  git -C "$APP" add -A
  # ┎ 실제 변경이 있을 때만 준비 커밋을 만들고, 준비 과정에서는 사용자·Sobaya 훅을 명시적으로 우회합니다.
  if ! git -C "$APP" diff --cached --quiet; then git -C "$APP" -c core.hooksPath=/dev/null commit -qm fixture; fi
}
# ┎ 릴리스 신원의 runtime 객체를 키 순서가 일정한 JSON으로 출력하여 버전·커밋·해시를 비교합니다.
identity() { jq -cS .runtime "$1"; }
# ┎ 각 독립 사례에 실제 소스·배포 파일·소비 저장소와 결정적인 전송·워커 대역을 준비합니다.
setup() {
  # ┎ 각 사례가 다른 사례의 상태를 물려받지 않도록 전용 임시 디렉터리를 만듭니다.
  WORK=$(mktemp -d "${TMPDIR:-/tmp}/sobaya-flow-draft.XXXXXX")
  # ┎ 종료 시 읽기 전용으로 설치된 파일도 지울 수 있도록 쓰기 권한을 복구하고 이 사례의 임시 자료를 정리합니다.
  trap 'chmod -R u+w "$WORK"; rm -rf "$WORK"' EXIT
  # ┎ 소스 경로의 작은따옴표와 설치 경로의 공백을 포함해 경로 인용 처리를 함께 검증합니다.
  SOURCE="$WORK/source's path"; STORE="$WORK/store with spaces"; CONSUMER="$WORK/consumer"
  # ┎ 두 개의 정확한 시험 버전으로 설치·동기화·업그레이드와 되돌림을 구분합니다.
  V1=1.0.0-rc.1; V2=1.0.0-rc.2
  # ┎ 소스, 소비 프로젝트, 배포 결과, 금지 호출 대역의 전용 디렉터리를 만듭니다.
  mkdir -p "$SOURCE" "$CONSUMER" "$WORK/releases" "$WORK/sentinel-bin"
  # ┎ 현재 체크아웃의 실제 런타임 파일을 복제합니다. 원본 파일은 변경하지 않으며, 커밋된 HEAD만 복제하는 방식은 아닙니다.
  (cd "$ROOT"; tar -cf - AGENTS.md bin .githooks scripts tdd-set) | tar -xf - -C "$SOURCE"
  # ┎ 복제본의 실제 전체 검사 함수를 다른 이름으로 보존하여 호출 기록을 덧붙일 수 있게 합니다.
  sed 's/^contract_suite() {/fixture_contract_suite() {/' "$SOURCE/tdd-set/lib/contract.sh" > "$WORK/contract.fixture"
  # ┎ 예상한 함수 선언을 실제로 찾았는지 검사하여 계측이 빠진 테스트가 통과하지 못하게 합니다.
  grep -q '^fixture_contract_suite() {' "$WORK/contract.fixture" || fail 'fixture cannot instrument the actual suite runner'
  # ┎ 함수 이름만 바꾼 계측 준비본을 임시 소스에 넣습니다.
  cat "$WORK/contract.fixture" > "$SOURCE/tdd-set/lib/contract.sh"
  # ┎ 어느 버전의 런타임이 전체 검사를 실행했는지 기록하는 얇은 래퍼를 임시 소스에 추가합니다.
  cat >> "$SOURCE/tdd-set/lib/contract.sh" <<'TRACE_SUITE'
# ┎ 이 래퍼가 런타임의 기존 전체 검사 진입점을 대신 받습니다.
contract_suite() {
  # ┎ 호출된 런타임 옆의 버전 표식을 읽어 이벤트에 기록합니다. 소비 설정의 버전 문자열만 기록하는 것과 구별합니다.
  printf 'runtime-suite:%s\n' "$(cat "$(dirname "${BASH_SOURCE[0]}")/release-fixture-marker")" >> "$FIXTURE_LOG"
  # ┎ 원래 전체 검사 함수에 받은 인자를 그대로 전달하므로 실제 테스트 실행과 판정은 대역으로 바꾸지 않습니다.
  fixture_contract_suite "$@"
}
TRACE_SUITE
  # ┎ 임시 런타임 소스를 실제 Git 저장소로 만들어 커밋과 태그가 있는 배포 입력을 준비합니다.
  git -C "$SOURCE" init -q
  # ┎ 배포 준비 커밋에 쓸 고정된 테스트 작성자 이름을 지정합니다.
  git -C "$SOURCE" config user.name Fixture
  # ┎ 외부 개인 정보에 의존하지 않는 테스트 이메일을 지정합니다.
  git -C "$SOURCE" config user.email fixture@example.invalid
  # ┎ 배포 소스의 준비 커밋에서는 훅이 실행되지 않도록 합니다.
  git -C "$SOURCE" config core.hooksPath /dev/null
  # ┎ 첫 번째와 두 번째 버전 각각에 실제 커밋·태그·배포 묶음을 만듭니다.
  for version in "$V1" "$V2"; do
    # ┎ 실제 검사 래퍼가 읽을 버전 표식을 소스 파일에 넣습니다.
    printf '%s\n' "$version" > "$SOURCE/tdd-set/lib/release-fixture-marker"
    # ┎ 표식까지 포함한 런타임을 실제 Git 커밋으로 고정합니다.
    git -C "$SOURCE" add -A; git -C "$SOURCE" commit -qm "$version"
    # ┎ 방금 만든 커밋의 실제 전체 식별자를 가져옵니다.
    revision=$(git -C "$SOURCE" rev-parse HEAD)
    # ┎ 정확한 버전 태그가 그 커밋을 가리키도록 합니다.
    git -C "$SOURCE" tag "v$version" "$revision"
    # ┎ 기존의 실제 배포 생성기로 아카이브와 매니페스트를 만듭니다. 내려받는 네트워크나 릴리스 게시 과정은 여기서 검증하지 않습니다.
    /bin/bash "$ROOT/scripts/package-release.sh" --source "$SOURCE" --version "$version" --commit "$revision" --output "$WORK/releases/$version" >/dev/null
  done
  # ┎ 허용되지 않은 curl 호출이 발생하면 표시를 남기고 실패하는 실행 파일 대역을 작성합니다.
  cat > "$WORK/sentinel-bin/curl" <<'SENTINEL'
#!/bin/bash
# ┎ 예상 밖의 네트워크 호출이 있었다는 흔적을 남깁니다.
printf 'unexpected network\n' >> "$NETWORK_LOG"
# ┎ 네트워크 대역은 실제 요청을 보내지 않고 구별 가능한 오류 코드로 종료합니다.
exit 93
SENTINEL
  # ┎ 같은 금지 대역을 codex 이름에도 두어 실제 유료 모델 호출을 막고 기록합니다.
  cp "$WORK/sentinel-bin/curl" "$WORK/sentinel-bin/codex"
  # ┎ PATH에서 대역을 실제 명령처럼 실행할 수 있도록 실행 권한을 부여합니다.
  chmod 755 "$WORK/sentinel-bin/curl" "$WORK/sentinel-bin/codex"
  # ┎ 대역 디렉터리를 PATH 앞에 두고 금지 호출 기록 경로를 자식 프로세스에 전달합니다. 절대 경로 호출까지 가로채는 장치는 아닙니다.
  export NETWORK_LOG="$WORK/network.log" PATH="$WORK/sentinel-bin:$PATH"
  # ┎ 실행 순서·워커 프롬프트·소비 설정 위치를 공유할 테스트 전용 환경값을 지정합니다.
  export FIXTURE_LOG="$WORK/events" FIXTURE_PROMPTS="$WORK/prompts" FIXTURE_ROOT="$CONSUMER"
  # ┎ 새 사례의 이벤트와 프롬프트 기록을 빈 상태로 시작합니다.
  : > "$FIXTURE_LOG"; : > "$FIXTURE_PROMPTS"
  # ┎ 유료 모델 대신 실행할 결정적인 셸 워커를 작성합니다. 모델의 추론 품질이나 실제 리뷰 판단은 이 대역이 검증하지 않습니다.
  cat > "$WORK/worker.sh" <<'WORKER'
#!/bin/bash
# ┎ 워커 대역도 명령 실패와 설정되지 않은 변수를 숨기지 않게 합니다.
set -eu
# ┎ 표준 입력으로 받은 실제 런타임 프롬프트를 기록하여 지침 경로를 나중에 확인합니다.
cat >> "$FIXTURE_PROMPTS"
# ┎ 구현 역할인지 리뷰 역할인지 기록하여 호출 순서와 역할 분리를 관찰합니다.
printf 'worker:%s\n' "$SOBAYA_ROLE" >> "$FIXTURE_LOG"
# ┎ 구현 역할일 때만 소스를 바꾸고, 리뷰 역할에서는 소스를 수정하지 않습니다.
if [ "$SOBAYA_ROLE" = implement ]; then
  # ┎ 항상 0을 반환하던 앱 구현을 두 수를 더하는 구현으로 바꾸어 실제 Node 테스트를 통과시키는 최소 변경을 합니다.
  printf 'exports.add = (a, b) => a + b;\n' > "$SOBAYA_APP/impl.js"
  # ┎ 보호 검사를 시험하는 사례에서만 의도적인 버전 설정 변조를 수행합니다.
  if [ "${FIXTURE_TAMPER:-0}" = 1 ]; then
    # ┎ 소비 설정의 런타임 버전을 설치하지 않은 9.0.0으로 바꾼 임시 JSON을 만듭니다.
    jq '.runtime.version="9.0.0"' "$FIXTURE_ROOT/sobaya.json" > "$FIXTURE_ROOT/pin.tmp"
    # ┎ 변조한 JSON으로 실제 설정 파일을 교체하여 런타임이 워커의 보호 입력 변경을 발견해야 하도록 합니다.
    mv "$FIXTURE_ROOT/pin.tmp" "$FIXTURE_ROOT/sobaya.json"
  fi
fi
# ┎ 구현·리뷰 대역 모두 done 결과를 반환합니다. 이후 실제 하네스가 검사·커밋·리뷰 상태를 확인해야 통과하며, 이 응답만으로 성공을 인정하는 테스트가 아닙니다.
printf '%s\n' '{"status":"done","summary":"Fixture implementation or independent review","reason":""}'
WORKER
  # ┎ 셸 명령 대역 하나만 허용하고 구현·리뷰 모두 그 대역을 쓰며, 승인당 최대 5회·호출당 20초·자동 승격 없음으로 정책을 고정합니다.
  jq -n --arg worker "$WORK/worker.sh" '{version:1,mode:"selected",default_worker:"fixture",review_worker:"fixture",max_calls:5,timeout_seconds:20,workers:{fixture:{adapter:"command",command:["/bin/bash",$worker],model:"fixture",guidance:"guided"}},escalation:[]}' > "$WORK/policy.json"
}
# ┎ 정확한 시험 버전에 대응하는 로컬 매니페스트 경로를 만드는 공통 도우미입니다.
manifest() { printf '%s/releases/%s/sobaya-%s.json\n' "$WORK" "$1" "$1"; }
# ┎ 정확한 시험 버전에 대응하는 로컬 배포 아카이브 경로를 만드는 공통 도우미입니다.
archive() { printf '%s/releases/%s/sobaya-%s.tar.gz\n' "$WORK" "$1" "$1"; }
# ┎ 공통 설치 도우미는 지정 버전 설치와 반환 신원·경로·안정 실행기의 존재를 함께 확인합니다.
install_version() {
  # ┎ 소비 루트와 외부 설치 저장소를 명시하고 실제 로컬 매니페스트·아카이브를 설치기에 전달합니다.
  invoke /bin/bash "$INSTALLER" --root "$CONSUMER" --install-root "$STORE" --version "$1" --manifest "$(manifest "$1")" --archive "$(archive "$1")"
  # ┎ 설치 명령이 성공 종료했는지 확인합니다.
  okay
  # ┎ 표준 출력이 JSON 하나이며 매니페스트의 runtime 신원과 예정된 버전별 설치 경로를 정확히 반환하는지 확인합니다.
  jq -e -s --argjson pin "$(identity "$(manifest "$1")")" --arg path "$STORE/runtimes/$1/runtime" 'length==1 and .[0].runtime==$pin and .[0].runtime_path==$path' "$WORK/stdout" >/dev/null || fail 'incorrect installed identity/path'
  # ┎ 버전과 무관한 고정 위치의 sobaya 실행기에 실행 권한이 있는지 확인합니다.
  [ -x "$STORE/bin/sobaya" ] || fail 'stable launcher is missing'
}
# ┎ 공통 CLI 도우미는 항상 소비 루트와 설치 저장소를 명시한 뒤 나머지 인자를 그대로 전달합니다.
cli() { invoke "$STORE/bin/sobaya" "$1" --root "$CONSUMER" --install-root "$STORE" "${@:2}"; }
# ┎ 두 모드가 같은 실제 Node 앱 검사를 사용하도록 소비 프로젝트를 준비하는 공통 도우미입니다.
app_fixture() {
  # ┎ 이 앱 준비에 사용할 프로젝트 모드 또는 종속 모드를 저장합니다.
  MODE=$1
  # ┎ 프로젝트 모드에서는 워크스페이스와 앱의 Git 저장소를 구분하여 준비합니다.
  if [ "$MODE" = project ]; then
    # ┎ 기존 프로젝트 방식의 brain 디렉터리와 apps/calculator 앱을 만듭니다.
    APP="$CONSUMER/apps/calculator"; mkdir -p "$CONSUMER/brain" "$APP"
    # ┎ 연결 과정이 보존해야 할 기존 지식 파일을 준비합니다.
    printf 'existing knowledge\n' > "$CONSUMER/brain/keep.md"
    # ┎ 덮어쓰면 안 되는 기존 워크스페이스 지침을 준비합니다.
    printf '# Existing workspace instructions\n' > "$CONSUMER/AGENTS.md"
    # ┎ 워크스페이스 자체도 실제 Git 저장소로 만듭니다.
    git -C "$CONSUMER" init -q
    # ┎ 앱들이 별도 Git 저장소라는 전제에 맞춰 워크스페이스에서 apps 전체를 무시합니다.
    printf '/apps/\n' > "$CONSUMER/.gitignore"
    # ┎ 워크스페이스의 기존 파일을 실제 커밋으로 남깁니다. 이는 준비 커밋이므로 훅은 우회합니다.
    git -C "$CONSUMER" add .; git -C "$CONSUMER" -c user.name=Fixture -c user.email=fixture@example.invalid -c core.hooksPath=/dev/null commit -qm workspace
  # ┎ 종속 모드에서는 소비 프로젝트 자체를 앱으로 사용하고 별도 앱 디렉터리를 만들지 않습니다.
  else APP="$CONSUMER"; fi
  # ┎ 앱을 독립된 실제 Git 저장소로 초기화합니다.
  git -C "$APP" init -q
  # ┎ 앱 커밋에 쓸 고정된 테스트 작성자 이름을 지정합니다.
  git -C "$APP" config user.name Fixture
  # ┎ 앱 커밋에 쓸 고정된 테스트 이메일을 지정합니다.
  git -C "$APP" config user.email fixture@example.invalid
  # ┎ 개인 서명 도구 설정 때문에 테스트 커밋이 막히지 않도록 서명을 끕니다.
  git -C "$APP" config commit.gpgsign false
  # ┎ 실제 Node 전체 테스트 명령과 린트 명령을 기존 앱 지침에 선언합니다. 소비자 지침 보존 검사의 기준 자료입니다.
  printf '# Existing app\n- Test: `node --test suite.test.js`\n- Lint: `node lint.cjs`\n' > "$APP/AGENTS.md"
  # ┎ 린트 대역은 실제 Node 프로세스로 실행되며 호출을 기록하고 환경값으로 성공·실패를 결정합니다. 실제 제품 린터의 규칙은 검증하지 않습니다.
  printf 'require("node:fs").appendFileSync(process.env.FIXTURE_LOG, "lint\\n"); process.exit(process.env.FIXTURE_LINT === "fail" ? 1 : 0);\n' > "$APP/lint.cjs"
  # ┎ 승인 기준으로 사용할 작은 앱 요구 문서를 준비합니다. 원래 사용자 저장소의 spec.md를 수정하는 동작이 아닙니다.
  printf '# Goal\nAdd two positive integers.\n' > "$APP/spec.md"
  # ┎ 새 덧셈 테스트가 실제로 실패하도록 초기 구현은 항상 0을 반환하게 합니다.
  printf 'exports.add = (a, b) => 0;\n' > "$APP/impl.js"
  # ┎ 이미 존재하던 기준 테스트를 실제 Node 테스트 파일에 작성합니다.
  cat > "$APP/suite.test.js" <<'BASE_TEST'
// file: suite.test.js
// ┎ Node의 실제 테스트 러너를 불러와 실행 증거를 생성합니다.
const test = require('node:test');
// ┎ 실제 기대값 비교에 쓸 Node 엄격 단정 도구를 불러옵니다.
const assert = require('node:assert/strict');
// ┎ 설정 읽기와 이벤트 기록에 쓸 실제 파일 도구를 불러옵니다.
const fs = require('node:fs');
// ┎ 소비 설정의 파일 경로를 만들 도구를 불러옵니다.
const path = require('node:path');
// ┎ 기존 테스트가 새 설치·bump 과정에서도 실제로 실행되는지 보여 주는 기준 테스트입니다.
test('existingBaseline', () => {
  // ┎ 이 검사 시점에 소비 프로젝트가 가리키는 런타임 버전을 설정에서 읽습니다.
  const version = JSON.parse(fs.readFileSync(path.join(process.env.FIXTURE_ROOT, 'sobaya.json'))).runtime.version;
  // ┎ 전체 검사에서 관찰한 설정 버전을 기록합니다. 실제 런타임 버전 선택은 별도의 runtime-suite 표식으로 확인합니다.
  fs.appendFileSync(process.env.FIXTURE_LOG, 'suite:' + version + '\n');
  // ┎ 여러 앱을 검사할 때 어느 앱과 버전이 실행됐는지 기록합니다.
  fs.appendFileSync(process.env.FIXTURE_LOG, 'suite-app:' + __dirname + ':' + version + '\n');
  // ┎ 테스트 실패 주입값이 fail이면 실제 Node 단정 실패를 발생시킵니다.
  assert.notEqual(process.env.FIXTURE_SUITE, 'fail');
});
BASE_TEST
  # ┎ 사람 승인 절차를 시험할 고정된 앱 계획을 작성합니다. 아래 한 항목은 이 테스트용 요구이며 실제 사용자 계획을 생성·승인하는 동작이 아닙니다.
  cat > "$APP/failed-test.md" <<'PLAN'
# Plan
## Add
```js
// file: suite.test.js
```
# ┎ 계획에는 아직 완료하지 않은 installedAdds 항목 하나를 둡니다. 실행기가 검증 후에만 체크해야 합니다.
- [ ] installedAdds — sums inputs
```js
// ┎ 실제 앱의 add(1, 2)가 정확히 3이어야 하므로 초기 구현에서 RED, 대역이 소스를 고친 뒤 GREEN이 됩니다.
test('installedAdds', () => assert.equal(require('./impl.js').add(1, 2), 3));
```
PLAN
  # ┎ 소비 프로젝트에 이미 존재하는 하위 apps 구조를 준비합니다.
  mkdir -p "$APP/apps/existing-subproject"
  # ┎ 연결 뒤에도 남아 있어야 할 기존 하위 프로젝트 내용을 넣습니다.
  printf 'existing layout\n' > "$APP/apps/existing-subproject/keep.txt"
  # ┎ 종속 모드에서만 하위 프로젝트 표시 파일을 넣어 프로젝트 모드의 평평한 앱 규칙을 잘못 적용하지 않는지 시험합니다.
  [ "$MODE" != dependency ] || printf '{"private":true}\n' > "$APP/apps/existing-subproject/package.json"
  # ┎ 위 공통 준비 자료를 훅을 우회하는 준비 커밋으로 고정합니다.
  commit_app
  # ┎ 앱의 실제 워크트리별 Git 디렉터리를 조회하여 승인·사용량·연결 메타데이터 위치를 정합니다. .git이 디렉터리라고 가정하지 않습니다.
  META=$(git -C "$APP" rev-parse --absolute-git-dir)/sobaya
  # ┎ 각 앱은 린트·테스트 성공, 워커 변조 없음 상태로 시작합니다.
  export FIXTURE_LINT=pass FIXTURE_SUITE=pass FIXTURE_TAMPER=0
}
# ┎ 공통 연결 도우미는 모드별 초기 연결 명령을 만들고 성공을 요구합니다.
connect() {
  # ┎ 프로젝트 모드는 연결할 앱 경로와 모드·첫 버전을 명시합니다.
  if [ "$MODE" = project ]; then cli init --mode "$MODE" --version "$V1" --app "$APP"
  # ┎ 종속 모드는 소비 루트 자체를 쓰므로 별도 앱 인자 없이 연결합니다.
  else cli init --mode "$MODE" --version "$V1"; fi
  # ┎ 초기 연결이 성공했는지 확인합니다.
  okay
}
# ┎ 실행기의 깨끗한 작업 트리 요건을 만족하도록 연결이 만든 추적 파일을 준비 커밋에 담습니다.
seal_connection() {
  # ┎ 앱에 생긴 연결 파일을 공통 준비 커밋 도우미로 고정합니다.
  commit_app
  # ┎ 프로젝트 모드에서는 워크스페이스 쪽 변경도 별도로 커밋합니다.
  if [ "$MODE" = project ]; then
    # ┎ 워크스페이스 연결 설정을 실제 인덱스에 올립니다.
    git -C "$CONSUMER" add .
    # ┎ 워크스페이스에 변경이 있을 때만 준비 커밋을 만들며 훅 검증과 혼동하지 않도록 훅은 우회합니다.
    if ! git -C "$CONSUMER" diff --cached --quiet; then git -C "$CONSUMER" -c user.name=Fixture -c user.email=fixture@example.invalid -c core.hooksPath=/dev/null commit -qm connection; fi
  fi
}
# ┎ 공통 런타임 호출 도우미는 같은 동작을 두 모드의 올바른 앱에 전달합니다.
runtime_cli() {
  # ┎ 프로젝트 모드에서는 명령 뒤에 대상 앱 경로와 나머지 인자를 붙입니다.
  if [ "$MODE" = project ]; then cli "$1" --app "$APP" "${@:2}"
  # ┎ 종속 모드에서는 소비 루트에 명령과 나머지 인자를 전달합니다.
  else cli "$1" "${@:2}"; fi
}
# ┎ 공통 pin 검사는 소비 lock의 버전·커밋·해시가 해당 릴리스 매니페스트와 모두 일치하는지 확인합니다.
assert_pin() { identity "$CONSUMER/sobaya.lock" > "$WORK/pin.actual"; identity "$(manifest "$1")" > "$WORK/pin.expected"; same "$WORK/pin.actual" "$WORK/pin.expected"; }
# ┎ 공통 로컬 실행 검사는 PATH에 둔 curl·codex 금지 대역이 한 번도 호출되지 않았음을 요구합니다. 다른 전송 도구나 절대 경로 호출의 부재까지 증명하지는 않습니다.
assert_no_network() { [ ! -e "$NETWORK_LOG" ] || fail 'local execution invoked network/provider'; }

# ┎ 사례 1은 실제 배포 파일을 정확히 설치하고 반복 설치를 보존하며, 내려받기 분기의 요청 인자와 저장 결과를 전송 대역으로 확인합니다.
install_pins_real_release_and_transport() {
  # ┎ 설치가 소비자의 기존 지침을 바꾸지 않아야 함을 확인할 기준 파일을 만듭니다.
  printf 'keep\n' > "$CONSUMER/AGENTS.md"
  # ┎ 설치 전 소비 디렉터리의 내용·경로·권한·링크를 공통 스냅샷으로 저장합니다.
  snapshot "$CONSUMER" "$WORK/consumer.before"
  # ┎ 공통 설치 도우미로 첫 버전을 설치하고 신원·경로·안정 실행기를 검증합니다.
  install_version "$V1"
  # ┎ 설치된 첫 버전의 실제 런타임 디렉터리를 지정합니다.
  RUNTIME="$STORE/runtimes/$V1/runtime"
  # ┎ 실행기 설치 결과에 Git 메타데이터가 섞이지 않았는지 확인합니다.
  [ ! -e "$RUNTIME/.git" ] || fail 'installed runtime contains Git metadata'
  # ┎ 설치한 런타임이 첫 버전의 표식 파일을 포함하는지 확인합니다.
  contains "$RUNTIME/tdd-set/lib/release-fixture-marker" "$V1"
  # ┎ 설치 저장소가 보관한 원본 아카이브가 입력 아카이브와 바이트 단위로 같은지 확인합니다.
  same "$(archive "$V1")" "$STORE/runtimes/$V1/archive.tar.gz"
  # ┎ 아카이브의 파일 목록에서 디렉터리 항목과 최상위 sobaya 접두사를 제거하여 비교할 상대 경로를 만듭니다.
  tar -tzf "$(archive "$V1")" | sed '/\/$/d;s|^sobaya/||' > "$WORK/members"
  # ┎ 아카이브의 각 파일을 하나씩 읽어 설치된 대응 파일과 완전히 같아야 한다고 요구합니다.
  while IFS= read -r file; do tar -xOzf "$(archive "$V1")" "sobaya/$file" > "$WORK/blob"; same "$WORK/blob" "$RUNTIME/$file"; done < "$WORK/members"
  # ┎ 실행기에는 실행 권한이 있고 일반 지침 파일에는 실행 권한이 없음을 확인합니다. 모든 파일의 정확한 모드를 하나씩 단정하는 줄은 아닙니다.
  [ -x "$RUNTIME/bin/sobaya" ] && [ ! -x "$RUNTIME/AGENTS.md" ] || fail 'installed executable distinction changed'
  # ┎ 설치 후 소비 디렉터리가 설치 전 스냅샷과 동일한지 확인합니다.
  snapshot "$CONSUMER" "$WORK/consumer.after"; same "$WORK/consumer.before" "$WORK/consumer.after"
  # ┎ 같은 버전을 다시 설치해도 설치 저장소의 경로·내용·권한·링크가 달라지지 않는지 확인합니다.
  snapshot "$STORE" "$WORK/store.before"; install_version "$V1"; snapshot "$STORE" "$WORK/store.after"; same "$WORK/store.before" "$WORK/store.after"
  # ┎ 이 사례의 내려받기 단계에서는 금지 curl을 로컬 파일 복사 대역으로 교체합니다. 실제 HTTP·TLS·리다이렉트 동작은 실행하지 않습니다.
  cat > "$WORK/sentinel-bin/curl" <<'CURL'
#!/bin/bash
# ┎ 전송 대역에서 누락된 값이나 실패를 숨기지 않도록 합니다.
set -eu
# ┎ 설치기가 curl에 넘긴 전체 인자를 줄별로 기록합니다.
printf '%s\n' "$@" > "$CURL_ARGS"
# ┎ 다운로드 출력 파일이 아직 지정되지 않았음을 표시합니다.
out=
# ┎ 전송 대역이 받은 인자를 모두 읽어 출력 경로와 URL을 찾습니다.
while [ "$#" -gt 0 ]; do
  # ┎ 출력 옵션의 다음 값을 저장하고 나머지 인자를 URL 후보로 받습니다. 이 대역은 curl 옵션의 실제 의미를 해석하지 않습니다.
  case "$1" in --output|-o) out=$2; shift 2 ;; *) url=$1; shift ;; esac
done
# ┎ 정확한 두 번째 버전의 GitHub Releases 아카이브 URL을 요청했는지 검사합니다.
[ "$url" = "https://github.com/team-poem/sobaya/releases/download/v1.0.0-rc.2/sobaya-1.0.0-rc.2.tar.gz" ] || exit 94
# ┎ 네트워크 대신 준비된 실제 아카이브를 지정된 다운로드 경로로 복사합니다.
cp "$CURL_ARCHIVE" "$out"
CURL
  # ┎ 대역이 기록할 인자 파일과 대신 전달할 두 번째 버전 아카이브를 지정합니다.
  export CURL_ARGS="$WORK/curl-args" CURL_ARCHIVE="$(archive "$V2")"
  # ┎ 로컬 아카이브 인자를 생략하여 설치기의 내려받기 분기를 호출합니다. 매니페스트는 여전히 로컬에서 제공합니다.
  invoke /bin/bash "$INSTALLER" --root "$CONSUMER" --install-root "$STORE" --version "$V2" --manifest "$(manifest "$V2")"
  # ┎ 설치 성공과 curl 인자에 HTTP 실패 처리·프로토콜 제한·HTTPS 값·리다이렉트 프로토콜 옵션이 포함됐는지 확인합니다. 옵션의 순서나 연결까지 검사하는 단정은 아닙니다.
  okay; contains "$CURL_ARGS" '--fail'; contains "$CURL_ARGS" '--proto'; contains "$CURL_ARGS" '=https'; contains "$CURL_ARGS" '--proto-redir'
  # ┎ 내려받기 분기가 저장한 아카이브가 대역이 제공한 실제 배포 파일과 동일한지 확인합니다.
  same "$(archive "$V2")" "$STORE/runtimes/$V2/archive.tar.gz"
}
# ┎ 사례 2는 잘못된 신원과 위험한 아카이브를 거부하며 기존 설치를 바꾸지 않아야 함을 검증합니다.
install_rejects_identity_and_unsafe_payload() {
  # ┎ 정상 첫 버전을 설치하고 이후 거부 동작이 보존해야 할 설치 저장소를 기록합니다.
  install_version "$V1"; snapshot "$STORE" "$WORK/store.before"
  # ┎ 매니페스트 형식·경로·정확한 버전·커밋·해시의 잘못된 값과 형식은 맞지만 내용이 다른 0 해시·0 커밋을 각각 시험합니다.
  for filter in '.manifest_version=2' '.artifact="../escape"' '.runtime.version="latest"' '.runtime.commit="HEAD"' '.runtime.sha256="bad"' '.runtime.sha256=("0"*64)' '.runtime.commit=("0"*40)'; do
    # ┎ 정상 두 번째 버전의 매니페스트에 현재 하나의 잘못된 조건을 주입합니다.
    jq "$filter" "$(manifest "$V2")" > "$WORK/bad.json"
    # ┎ 변조한 매니페스트와 원래 두 번째 버전 아카이브로 설치를 시도합니다.
    invoke /bin/bash "$INSTALLER" --root "$CONSUMER" --install-root "$STORE" --version "$V2" --manifest "$WORK/bad.json" --archive "$(archive "$V2")"
    # ┎ 잘못된 신원은 코드 2로 실패하고 성공 JSON을 내지 않으며 오류 설명을 남겨야 합니다.
    [ "$RC" -eq 2 ] && [ ! -s "$WORK/stdout" ] && [ -s "$WORK/stderr" ] || fail 'invalid release identity accepted'
    # ┎ 거부 뒤 설치 저장소가 정상 첫 버전만 있던 상태와 동일한지 확인합니다.
    snapshot "$STORE" "$WORK/store.after"; same "$WORK/store.before" "$WORK/store.after"
  done
  # ┎ 유효한 JSON 객체 두 개를 이어 붙여 매니페스트가 단일 객체여야 하는지 시험합니다.
  cat "$(manifest "$V2")" "$(manifest "$V2")" > "$WORK/bad.json"
  # ┎ 여러 객체가 담긴 매니페스트를 설치기에 전달합니다.
  invoke /bin/bash "$INSTALLER" --root "$CONSUMER" --install-root "$STORE" --version "$V2" --manifest "$WORK/bad.json" --archive "$(archive "$V2")"
  # ┎ 매니페스트 문제로 코드 2, 빈 표준 출력, manifest 진단을 요구합니다.
  invalid manifest
  # ┎ 필수 파일 누락, 심볼릭 링크, 허용 밖 파일, 중복 경로, 하드 링크, FIFO, 상위 경로 이동, 절대 경로를 각각 준비합니다.
  for shape in missing symlink unexpected duplicate hardlink fifo traversal absolute; do
    # ┎ 각 위험 사례를 만들기 전에 임시 소스를 정상 두 번째 버전 커밋으로 되돌립니다. 사용자 체크아웃에는 적용하지 않습니다.
    git -C "$SOURCE" reset --hard -q "v$V2"
    # ┎ 소스 트리만 바꿔 만들 수 있는 세 종류의 위험 입력을 구분합니다.
    case "$shape" in
      # ┎ 필수 실행기 파일을 삭제하여 구성 파일 누락을 시험합니다.
      missing) rm "$SOURCE/bin/sobaya" ;;
      # ┎ 임시 소스 밖의 보존 파일을 가리키는 심볼릭 링크를 배포 내용에 넣습니다.
      symlink) printf 'keep\n' > "$WORK/outside"; ln -s "$WORK/outside" "$SOURCE/tdd-set/lib/unsafe" ;;
      # ┎ 정해진 런타임 파일 집합에 없는 파일을 소스 루트에 추가합니다.
      unexpected) printf 'private\n' > "$SOURCE/private.txt" ;;
    esac
    # ┎ 변조한 소스 상태를 실제 커밋으로 만들며, 파일 변경이 없는 종류도 별도 커밋 식별자를 갖게 합니다.
    git -C "$SOURCE" add -A; git -C "$SOURCE" commit --allow-empty -qm "$shape"
    # ┎ 위험 입력의 실제 Git 커밋 식별자를 저장합니다.
    revision=$(git -C "$SOURCE" rev-parse HEAD)
    # ┎ 위험 아카이브에도 기본 런타임의 허용 경로 목록을 사용하도록 해당 커밋의 파일 목록을 읽습니다.
    git -C "$SOURCE" ls-tree -r --name-only "$revision" -- \
      # ┎ 루트 지침·실행기·루트 훅·brain 인덱스 도구를 기본 배포 대상으로 포함합니다.
      AGENTS.md bin/sobaya .githooks/pre-commit scripts/brain-index.sh \
      # ┎ 포맷 검사 해석·인덱스 렌더링·초안 실행 도구를 기본 배포 대상으로 포함합니다.
      scripts/formatter-listing.awk scripts/index-render.awk scripts/probe.sh \
      # ┎ 설정·공통 경로 처리·워크스페이스 검사 도구를 기본 배포 대상으로 포함합니다.
      scripts/setup.sh scripts/tools-common.sh scripts/workspace-check.sh \
      # ┎ 공통 개발 계약·런타임 설명·요구사항 템플릿을 기본 배포 대상으로 포함합니다.
      tdd-set/AGENTS.md tdd-set/README.md tdd-set/spec-template.md \
      # ┎ 계획 템플릿과 워커 결과 스키마를 기본 배포 대상으로 포함합니다.
      tdd-set/failed-test-template.md tdd-set/worker-result.schema.json \
      # ┎ 런타임 실행 명령·라이브러리·훅·정책·스킬 아래의 파일까지 목록에 저장합니다.
      tdd-set/bin/ tdd-set/lib/ tdd-set/hooks/ tdd-set/policies/ tdd-set/skills/ > "$WORK/payload-paths"
    # ┎ 파일 경로를 셸 배열로 읽어 공백이 있는 경로도 별도 인자로 유지합니다.
    payload=(); while IFS= read -r file; do payload+=("$file"); done < "$WORK/payload-paths"
    # ┎ 허용 밖 파일 사례에서만 private.txt를 기본 허용 집합에 추가합니다.
    [ "$shape" != unexpected ] || payload+=(private.txt)
    # ┎ Git 커밋 표식이 있는 실제 tar 아카이브를 만들되, 설치기가 거부해야 하는 내용은 그대로 포함합니다.
    git -C "$SOURCE" archive --format=tar --prefix=sobaya/ "$revision" -- "${payload[@]}" > "$WORK/unsafe.tar"
    # ┎ tar에 나중에 덧붙일 위험 항목을 각 사례의 전용 경로에 준비합니다.
    extra="$WORK/member-$shape"; mkdir -p "$extra/sobaya/bin" "$extra/sobaya/tdd-set/lib"
    # ┎ 절대 경로 탈출 시 바뀌면 안 되는 외부 표적 파일을 만듭니다.
    printf 'keep\n' > "$WORK/absolute-target"
    # ┎ tar 포맷에 직접 추가해야 하는 위험 항목의 종류를 구분합니다.
    case "$shape" in
      # ┎ 같은 경로를 두 번 포함하는 중복 항목을 준비합니다.
      duplicate)
        # ┎ 기존 bin/sobaya와 내용이 다른 중복 파일을 만듭니다.
        printf 'duplicate\n' > "$extra/sobaya/bin/sobaya"
        # ┎ 같은 sobaya/bin/sobaya 경로를 tar 뒤에 추가하며 macOS의 부가 메타데이터 생성을 막습니다.
        COPYFILE_DISABLE=1 tar -rf "$WORK/unsafe.tar" -C "$extra" sobaya/bin/sobaya
        # ┎ 실제로 같은 멤버 이름이 두 번 들어갔는지 확인하여 잘못 만든 위험 입력이 테스트를 무의미하게 하지 못하게 합니다.
        [ "$(tar -tf "$WORK/unsafe.tar" | grep -Fxc sobaya/bin/sobaya)" -eq 2 ] || fail 'duplicate fixture did not contain two members' ;;
      # ┎ 일반 파일처럼 보이는 하드 링크 항목을 별도로 준비합니다.
      hardlink)
        # ┎ 하드 링크가 공유할 원본 내용을 만듭니다.
        printf 'linked\n' > "$extra/sobaya/tdd-set/lib/link-source"
        # ┎ 같은 파일 내용을 가리키는 실제 하드 링크를 생성합니다.
        ln "$extra/sobaya/tdd-set/lib/link-source" "$extra/sobaya/tdd-set/lib/unsafe"
        # ┎ 원본과 링크를 함께 tar에 추가하여 tar가 두 번째 항목을 하드 링크로 기록하게 합니다.
        COPYFILE_DISABLE=1 tar -rf "$WORK/unsafe.tar" -C "$extra" sobaya/tdd-set/lib/link-source sobaya/tdd-set/lib/unsafe
        # ┎ tar 목록에 하드 링크 유형이 나타나는지 확인하여 이 사례가 실제로 하드 링크 거부를 시험하는지 검증합니다.
        tar -tvf "$WORK/unsafe.tar" > "$WORK/listing"; grep -Eq '^h.*sobaya/tdd-set/lib/unsafe' "$WORK/listing" || fail 'hardlink fixture type missing' ;;
      # ┎ 압축 해제 시 일반 파일이 아닌 FIFO가 생기는 입력을 준비합니다.
      fifo)
        # ┎ 실제 명명 파이프를 만들어 일반 파일과 구분되는 tar 항목을 얻습니다.
        mkfifo "$extra/sobaya/tdd-set/lib/unsafe"
        # ┎ FIFO 항목을 기존 tar에 덧붙입니다.
        COPYFILE_DISABLE=1 tar -rf "$WORK/unsafe.tar" -C "$extra" sobaya/tdd-set/lib/unsafe
        # ┎ tar 목록에 파이프 유형이 기록됐는지 확인하여 FIFO 위험 입력이 제대로 준비됐는지 검증합니다.
        tar -tvf "$WORK/unsafe.tar" > "$WORK/listing"; grep -Eq '^p.*sobaya/tdd-set/lib/unsafe' "$WORK/listing" || fail 'fifo fixture type missing' ;;
      # ┎ 설치 루트를 벗어나는 상대 경로와 절대 경로 항목을 준비합니다.
      traversal|absolute)
        # ┎ 탈출 항목이 기록하려는 내용을 만듭니다.
        printf 'escape\n' > "$extra/member-content"
        # ┎ 기본은 상위 디렉터리를 벗어나는 경로이고, 절대 경로 사례에서는 보존 대상의 전체 경로를 사용합니다.
        member=sobaya/../../outside; [ "$shape" != absolute ] || member="$WORK/absolute-target"
        # ┎ 현재 tar 구현에 맞는 이름 변환 옵션으로 위험한 경로를 의도적으로 보존합니다.
        case "$(tar --version)" in
          # ┎ BSD tar에서는 이름 치환과 절대 경로 보존 옵션으로 탈출 항목을 추가합니다.
          bsdtar*) COPYFILE_DISABLE=1 tar -rPf "$WORK/unsafe.tar" -s ",^member-content$,$member," -C "$extra" member-content ;;
          # ┎ GNU tar에서는 대응하는 이름 변환 옵션으로 같은 탈출 항목을 추가합니다.
          *'GNU tar'*) tar -rPf "$WORK/unsafe.tar" --transform="s,^member-content$,$member," -C "$extra" member-content ;;
          # ┎ 지원하지 않는 tar로 잘못된 위험 입력을 만들지 않도록 사례를 실패시킵니다.
          *) fail 'unsupported tar fixture generator' ;;
        esac
        # ┎ 위험 경로가 tar 생성 과정에서 안전한 경로로 정규화되지 않고 그대로 남았는지 확인합니다.
        tar -tf "$WORK/unsafe.tar" > "$WORK/listing"; grep -Fxq "$member" "$WORK/listing" || fail 'unsafe fixture path was normalized away' ;;
    esac
    # ┎ 위험 항목을 추가한 뒤에도 Git의 원래 커밋 표식이 유지되는지 확인합니다.
    [ "$(git get-tar-commit-id < "$WORK/unsafe.tar")" = "$revision" ] || fail 'unsafe fixture lost its commit marker'
    # ┎ 수정된 tar를 시간 정보 없는 gzip으로 압축합니다.
    gzip -n < "$WORK/unsafe.tar" > "$WORK/unsafe.tar.gz"
    # ┎ 위험 아카이브 자체의 실제 SHA-256을 구합니다.
    digest=$(shasum -a 256 "$WORK/unsafe.tar.gz"); digest=${digest%% *}
    # ┎ 수정된 아카이브의 실제 해시와 유지된 Git 커밋 표식을 매니페스트에 기록합니다. 추가된 항목까지 해당 커밋에 속한다는 뜻은 아닙니다.
    jq --arg commit "$revision" --arg sha "$digest" '.runtime.commit=$commit|.runtime.sha256=$sha' "$(manifest "$V2")" > "$WORK/bad.json"
    # ┎ 해시와 커밋 표식은 맞지만 구조가 위험한 아카이브의 설치를 시도합니다.
    invoke /bin/bash "$INSTALLER" --root "$CONSUMER" --install-root "$STORE" --version "$V2" --manifest "$WORK/bad.json" --archive "$WORK/unsafe.tar.gz"
    # ┎ 아카이브 문제로 코드 2, 빈 표준 출력, archive 진단을 요구합니다.
    invalid archive
    # ┎ 위험 입력을 거부한 뒤에도 기존 설치 저장소가 그대로인지 확인합니다.
    snapshot "$STORE" "$WORK/store.after"; same "$WORK/store.before" "$WORK/store.after"
    # ┎ 심볼릭 링크 사례에서는 링크 밖의 파일이 keep 내용 그대로인지 추가로 확인합니다.
    [ "$shape" != symlink ] || [ "$(cat "$WORK/outside")" = keep ] || fail 'archive followed outside symlink'
    # ┎ 어떤 위험 사례에서도 절대 경로 표적 파일이 덮어써지지 않았는지 확인합니다.
    [ "$(cat "$WORK/absolute-target")" = keep ] || fail 'archive wrote an absolute path'
  done
}
# ┎ 사례 3은 기존 설치 경로·다운로드 실패·동일 버전의 다른 신원·변조된 설치본을 보존하며 거부하는지 검증합니다.
install_preserves_existing_paths_and_failed_downloads() {
  # ┎ 정상 첫 버전을 설치하고 보존 기준을 기록합니다.
  install_version "$V1"; snapshot "$STORE" "$WORK/store.before"
  # ┎ 두 번째 버전의 설치 위치가 디렉터리·파일·정상 링크·끊어진 링크인 경우를 각각 시험합니다.
  for shape in directory file symlink dangling; do
    # ┎ 충돌을 만들 버전별 설치 위치를 지정합니다.
    dest="$STORE/runtimes/$V2"
    # ┎ 현재 종류에 맞는 기존 경로를 만들어 설치기가 덮어쓰거나 링크를 따라가면 안 되도록 합니다.
    case "$shape" in directory) mkdir "$dest" ;; file) printf 'keep\n' > "$dest" ;; symlink) mkdir "$WORK/target"; ln -s "$WORK/target" "$dest" ;; dangling) ln -s "$WORK/absent" "$dest" ;; esac
    # ┎ 충돌 대상까지 포함한 설치 저장소 상태를 기록합니다.
    snapshot "$STORE" "$WORK/conflict.before"
    # ┎ 이미 사용 중인 버전별 경로에 두 번째 버전 설치를 시도합니다.
    invoke /bin/bash "$INSTALLER" --root "$CONSUMER" --install-root "$STORE" --version "$V2" --manifest "$(manifest "$V2")" --archive "$(archive "$V2")"
    # ┎ 설치 경로 충돌로 코드 2, 빈 표준 출력, install 진단을 요구합니다.
    invalid install
    # ┎ 거부 뒤 충돌 경로와 기존 설치가 모두 그대로인지 확인합니다.
    snapshot "$STORE" "$WORK/conflict.after"; same "$WORK/conflict.before" "$WORK/conflict.after"
    # ┎ 끊어진 링크의 대상 디렉터리를 새로 만들지 않았는지 확인합니다.
    [ ! -e "$WORK/absent" ] || fail 'dangling target created'
    # ┎ 정상 링크 사례에서는 링크 대상 디렉터리에 어떤 파일도 생기지 않았는지 확인합니다.
    [ "$shape" != symlink ] || [ -z "$(ls -A "$WORK/target")" ] || fail 'symlink target changed'
    # ┎ 현재 충돌 준비 자료만 지워 다음 종류를 독립적으로 시험합니다.
    if [ -L "$dest" ] || [ -f "$dest" ]; then rm "$dest"; else rmdir "$dest"; fi
  done
  # ┎ 소비 프로젝트 내부의 cache를 설치 저장소로 지정하여 소스 바깥 설치 원칙을 시험합니다.
  invoke /bin/bash "$INSTALLER" --root "$CONSUMER" --install-root "$CONSUMER/cache" --version "$V1" --manifest "$(manifest "$V1")" --archive "$(archive "$V1")"
  # ┎ 소비 프로젝트 내부 설치를 install 진단으로 거부하도록 요구합니다.
  invalid install
  # ┎ 거부 과정에서 내부 cache 디렉터리조차 남기지 않았는지 확인합니다.
  [ ! -e "$CONSUMER/cache" ] || fail 'consumer-contained store was created'
  # ┎ 전송 대역을 일부 파일만 쓰고 실패하는 다운로드로 바꿉니다. 실제 통신 중단 대신 결정적인 실패를 주입합니다.
  cat > "$WORK/sentinel-bin/curl" <<'CURL_FAIL'
#!/bin/bash
# ┎ 다운로드 출력 경로를 찾을 때까지 받은 인자를 읽습니다.
while [ "$#" -gt 0 ]; do
  # ┎ 출력 옵션을 찾으면 부분 다운로드 내용만 쓰고 인자 탐색을 끝냅니다.
  case "$1" in --output|-o) printf partial > "$2"; break ;; esac
  # ┎ 출력 옵션이 아니면 다음 인자로 이동합니다.
  shift
done
# ┎ curl의 실패를 흉내 내는 코드 22로 종료합니다.
exit 22
CURL_FAIL
  # ┎ 로컬 아카이브 없이 설치를 호출하여 부분 다운로드 실패를 통과하게 합니다.
  invoke /bin/bash "$INSTALLER" --root "$CONSUMER" --install-root "$STORE" --version "$V2" --manifest "$(manifest "$V2")"
  # ┎ 다운로드 오류는 코드 2, 빈 표준 출력, download 진단으로 보고해야 합니다.
  invalid download
  # ┎ 실패한 다운로드가 기존 설치 저장소에 파일이나 경로를 남기지 않았는지 확인합니다.
  snapshot "$STORE" "$WORK/store.after"; same "$WORK/store.before" "$WORK/store.after"
  # ┎ 실패 뒤에도 첫 버전 실행기가 남아 있고 실행 가능해야 합니다.
  [ -x "$STORE/runtimes/$V1/runtime/bin/sobaya" ] || fail 'previous runtime lost'
  # ┎ 두 번째 버전의 커밋·해시는 유지한 채 버전·파일명만 첫 버전으로 바꾸어 동일 버전 이름을 다른 신원에 재사용하려고 합니다.
  jq --arg version "$V1" '.artifact=("sobaya-"+$version+".tar.gz")|.runtime.version=$version' "$(manifest "$V2")" > "$WORK/rebound.json"
  # ┎ 이미 설치된 첫 버전 이름에 다른 배포 내용을 설치하려고 시도합니다.
  invoke /bin/bash "$INSTALLER" --root "$CONSUMER" --install-root "$STORE" --version "$V1" --manifest "$WORK/rebound.json" --archive "$(archive "$V2")"
  # ┎ 동일 버전 신원 충돌을 install 진단으로 거부하도록 요구합니다.
  invalid install
  # ┎ 신원 충돌 거부 후에도 설치 저장소가 원래 그대로인지 확인합니다.
  snapshot "$STORE" "$WORK/store.after"; same "$WORK/store.before" "$WORK/store.after"
  # ┎ 설치된 실행기 파일의 변조를 준비하려고 소유자 쓰기 권한을 켭니다.
  chmod u+w "$STORE/runtimes/$V1/runtime/bin/sobaya"
  # ┎ 실행기 내용을 의도적으로 바꾸어 저장된 설치본이 배포 내용과 달라지게 합니다.
  printf 'tampered installed executable\n' > "$STORE/runtimes/$V1/runtime/bin/sobaya"
  # ┎ 변조된 상태 자체를 기록하여 재설치가 이를 몰래 복구하거나 덮어쓰지 못하게 합니다.
  snapshot "$STORE" "$WORK/tampered.before"
  # ┎ 정상 매니페스트·아카이브로 같은 버전 재설치를 요청합니다.
  invoke /bin/bash "$INSTALLER" --root "$CONSUMER" --install-root "$STORE" --version "$V1" --manifest "$(manifest "$V1")" --archive "$(archive "$V1")"
  # ┎ 기존 설치본의 변조를 install 진단으로 거부하도록 요구합니다.
  invalid install
  # ┎ 거부 시 변조된 증거까지 그대로 보존해야 하며 자동 복구로 덮어쓰지 않았는지 확인합니다.
  snapshot "$STORE" "$WORK/tampered.after"; same "$WORK/tampered.before" "$WORK/tampered.after"
}
# ┎ 사례 4는 두 모드의 초기 연결이 기존 지침·요구·계획과 디렉터리를 보존하며 임의 승인을 만들지 않아야 함을 검증합니다.
init_connects_both_modes_without_rewriting_contracts() {
  # ┎ 두 소비 모드가 공유할 첫 버전 런타임을 설치합니다.
  install_version "$V1"
  # ┎ 종속 모드와 프로젝트 모드를 별도 소비 디렉터리에서 각각 시험합니다.
  for mode in dependency project; do
    # ┎ 현재 모드의 소비 디렉터리와 설정 조회 위치를 지정합니다.
    CONSUMER="$WORK/$mode"; mkdir "$CONSUMER"; export FIXTURE_ROOT="$CONSUMER"
    # ┎ 앞서 설명한 공통 도우미로 해당 모드의 실제 Git·Node 앱을 준비합니다.
    app_fixture "$mode"
    # ┎ 연결 전 소비 루트의 기존 지침을 별도 보관합니다.
    cp "$CONSUMER/AGENTS.md" "$WORK/workspace-agents.saved"
    # ┎ 연결 전 앱의 지침·요구·계획 원본을 각각 보관합니다.
    for file in AGENTS.md spec.md failed-test.md; do cp "$APP/$file" "$WORK/$file.saved"; done
    # ┎ 초기 연결 후 lock 신원이 실제 첫 버전 매니페스트와 일치하는지 확인합니다.
    connect; assert_pin "$V1"
    # ┎ 설정 형식 버전이 1이고 요청한 모드와 정확한 첫 런타임 버전이 저장됐는지 확인합니다.
    jq -e --arg mode "$mode" --arg version "$V1" '.config_version==1 and .mode==$mode and .runtime.version==$version' "$CONSUMER/sobaya.json" >/dev/null || fail 'wrong mode configuration'
    # ┎ 앱 지침·요구·계획 파일이 연결 전과 바이트 단위로 같아야 합니다.
    for file in AGENTS.md spec.md failed-test.md; do same "$APP/$file" "$WORK/$file.saved"; done
    # ┎ 소비 루트 지침도 연결 전과 바이트 단위로 같아야 합니다.
    same "$CONSUMER/AGENTS.md" "$WORK/workspace-agents.saved"
    # ┎ 같은 연결을 반복한 뒤 소비 디렉터리 전체 스냅샷이 바뀌지 않는지 확인합니다.
    snapshot "$CONSUMER" "$WORK/connected.before"; connect; snapshot "$CONSUMER" "$WORK/connected.after"; same "$WORK/connected.before" "$WORK/connected.after"
    # ┎ 종속 모드는 brain 디렉터리를 임의로 만들지 않아야 합니다.
    [ "$mode" != dependency ] || [ ! -e "$CONSUMER/brain" ] || fail 'dependency mode created brain'
    # ┎ 기존 하위 앱 디렉터리에 있던 내용이 남아 있어야 합니다.
    contains "$APP/apps/existing-subproject/keep.txt" 'existing layout'
    # ┎ 프로젝트 모드의 기존 brain 지식 파일이 남아 있어야 합니다.
    [ "$mode" != project ] || contains "$CONSUMER/brain/keep.md" 'existing knowledge'
    # ┎ 초기 연결만으로 테스트 승인 상태 파일을 생성하지 않아야 합니다.
    [ ! -e "$META/state.json" ] || fail 'init invented test approval'
  done
  # ┎ 두 모드 초기 연결 동안 네트워크·유료 모델 금지 대역이 호출되지 않았는지 확인합니다.
  assert_no_network
}
# ┎ 사례 5는 실제 Git 커밋으로 기존 훅과 Sobaya 린트의 실행 순서·실패 차단·메시지 훅 전달·원본 보존을 검증합니다.
connected_hooks_preserve_original_behavior() {
  # ┎ 첫 런타임과 종속 모드의 실제 앱을 준비합니다.
  install_version "$V1"; app_fixture dependency
  # ┎ 소비자가 이미 쓰는 사용자 훅 디렉터리를 만듭니다.
  mkdir "$APP/custom-hooks"
  # ┎ 프로젝트 밖에 기존 pre-commit의 실제 대상을 작성합니다. 연결은 이 원본과 이를 가리키는 링크를 모두 보존해야 합니다.
  cat > "$WORK/original-pre" <<'PRE'
#!/bin/bash
# ┎ 원본 pre-commit이 실행됐다는 이벤트를 기록합니다.
printf 'original-pre\n' >> "$FIXTURE_LOG"
# ┎ 실패 주입값이 fail이면 원본 훅이 코드 17로 커밋을 거부합니다.
[ "${FIXTURE_ORIGINAL:-pass}" != fail ] || exit 17
PRE
  # ┎ Git이 원본 훅을 실행할 수 있도록 권한을 설정합니다.
  chmod 755 "$WORK/original-pre"
  # ┎ 사용자 훅 경로에 외부 원본을 가리키는 심볼릭 링크를 둡니다.
  ln -s "$WORK/original-pre" "$APP/custom-hooks/pre-commit"
  # ┎ pre-commit 외의 commit-msg 훅도 준비하여 다른 기존 훅이 계속 전달되는지 확인합니다.
  cat > "$APP/custom-hooks/commit-msg" <<'MESSAGE_HOOK'
#!/bin/bash
# ┎ 메시지 훅 내부의 명령 실패나 누락된 값은 숨기지 않습니다.
set -eu
# ┎ Git이 정확히 하나의 실제 메시지 파일 경로를 넘겨야 하며 아니면 코드 18로 거부합니다.
[ "$#" -eq 1 ] && [ -f "$1" ] || exit 18
# ┎ 넘겨받은 메시지 파일의 첫 줄을 기록해 성공 커밋의 메시지 전달을 확인합니다.
printf 'original-message:%s\n' "$(head -n 1 "$1")" >> "$FIXTURE_LOG"
MESSAGE_HOOK
  # ┎ 기존 commit-msg 훅에도 실행 권한을 줍니다.
  chmod 755 "$APP/custom-hooks/commit-msg"
  # ┎ Git이 상대 경로 custom-hooks를 원래 훅 디렉터리로 사용하게 합니다.
  git -C "$APP" config core.hooksPath custom-hooks
  # ┎ 준비 커밋을 만든 뒤 사용자 훅 디렉터리와 외부 링크 대상의 원본을 보존 기준으로 기록합니다.
  commit_app; snapshot "$APP/custom-hooks" "$WORK/hooks.before"; cp "$WORK/original-pre" "$WORK/original.saved"
  # ┎ Sobaya에 연결하고 연결 설정을 준비 커밋으로 고정합니다. 이 준비 커밋은 훅 검증과 구분하여 우회합니다.
  connect; seal_connection
  # ┎ 차단되어야 할 커밋들 앞의 HEAD를 저장합니다.
  before=$(git -C "$APP" rev-parse HEAD)
  # ┎ 사용자 변경 하나를 실제 인덱스에 올려 커밋 대상으로 준비합니다.
  printf 'user change\n' > "$APP/user.txt"; git -C "$APP" add user.txt
  # ┎ 원본 훅 실패 사례의 이벤트 기록을 비웁니다.
  : > "$FIXTURE_LOG"
  # ┎ 원본 pre-commit만 실패하도록 설정합니다.
  export FIXTURE_ORIGINAL=fail
  # ┎ 훅을 우회하지 않는 실제 Git 커밋을 시도합니다.
  invoke git -C "$APP" commit -m blocked-original
  # ┎ 커밋이 실패하고 HEAD가 바뀌지 않아야 원본 훅의 거부가 보존된 것입니다.
  [ "$RC" -ne 0 ] && [ "$(git -C "$APP" rev-parse HEAD)" = "$before" ] || fail 'original pre-commit failure bypassed'
  # ┎ 기록이 원본 pre-commit 한 줄뿐이어야 하므로 Sobaya 린트까지 실행하지 않고 중단했는지도 확인합니다.
  printf 'original-pre\n' > "$WORK/expected-events"; same "$FIXTURE_LOG" "$WORK/expected-events"
  # ┎ 다음 실패 사례와 앞선 이벤트가 섞이지 않도록 기록을 비웁니다.
  : > "$FIXTURE_LOG"
  # ┎ 원본 훅은 통과시키고 Sobaya가 호출할 린트만 실패시킵니다.
  export FIXTURE_ORIGINAL=pass FIXTURE_LINT=fail
  # ┎ 동일한 사용자 변경을 다시 실제 커밋하려고 시도합니다.
  invoke git -C "$APP" commit -m blocked-lint
  # ┎ 린트 실패도 커밋을 막고 HEAD를 유지해야 합니다.
  [ "$RC" -ne 0 ] && [ "$(git -C "$APP" rev-parse HEAD)" = "$before" ] || fail 'Sobaya lint failure bypassed'
  # ┎ 이벤트가 원본 pre-commit 다음 린트 순서로 정확히 두 줄이어야 합니다.
  printf 'original-pre\nlint\n' > "$WORK/expected-events"; same "$FIXTURE_LOG" "$WORK/expected-events"
  # ┎ 성공 사례를 별도로 관찰하도록 기록을 비웁니다.
  : > "$FIXTURE_LOG"
  # ┎ 린트를 통과시켜 원본 훅과 Sobaya 검사 모두 성공하게 합니다.
  export FIXTURE_LINT=pass
  # ┎ 실제 커밋이 성공 종료하는지 확인합니다.
  invoke git -C "$APP" commit -m both-pass; okay
  # ┎ 성공 시에도 처음 두 이벤트가 원본 훅 다음 린트 순서인지 확인합니다.
  head -n 2 "$FIXTURE_LOG" > "$WORK/actual-events"; same "$WORK/actual-events" "$WORK/expected-events"
  # ┎ 기존 메시지 훅이 실제 성공 커밋의 both-pass 메시지를 전달받았는지 확인합니다.
  contains "$FIXTURE_LOG" original-message:both-pass
  # ┎ 사용자 훅 디렉터리의 내용·권한·링크와 외부 원본 내용이 연결 전 그대로인지 확인합니다.
  snapshot "$APP/custom-hooks" "$WORK/hooks.after"; same "$WORK/hooks.before" "$WORK/hooks.after"; same "$WORK/original-pre" "$WORK/original.saved"
  # ┎ 훅 연결과 세 번의 실제 커밋 시도에서 금지 대역이 호출되지 않았는지 확인합니다.
  assert_no_network
}
# ┎ 사례 6은 이미 워크트리별 Git 설정이 켜진 저장소에서 연결된 워크트리만 훅 구성이 바뀌어야 함을 검증합니다. 설정 확장의 자동 마이그레이션은 시험하지 않습니다.
connection_keeps_linked_worktree_hooks_isolated() {
  # ┎ 첫 버전 런타임과 종속 모드 앱을 준비합니다.
  install_version "$V1"; app_fixture dependency
  # ┎ 연결하지 않을 주 체크아웃을 보존 기준으로 저장합니다.
  main=$APP
  # ┎ 주 체크아웃과 연결된 워크트리가 각각 사용할 훅 디렉터리를 만듭니다.
  mkdir "$WORK/main-hooks" "$WORK/linked-hooks"
  # ┎ 주 체크아웃 훅은 main-hook 이벤트만 기록하게 합니다.
  printf '#!/bin/bash\nprintf "main-hook\\n" >> "$FIXTURE_LOG"\n' > "$WORK/main-hooks/pre-commit"
  # ┎ 별도 워크트리 훅은 linked-hook 이벤트만 기록하게 합니다.
  printf '#!/bin/bash\nprintf "linked-hook\\n" >> "$FIXTURE_LOG"\n' > "$WORK/linked-hooks/pre-commit"
  # ┎ 두 원본 훅에 실행 권한을 부여합니다.
  chmod 755 "$WORK/main-hooks/pre-commit" "$WORK/linked-hooks/pre-commit"
  # ┎ 준비 단계에서 워크트리별 설정 확장을 켜 둡니다. 초기 연결이 이 공통 설정을 변경해도 되는지 시험하는 사례는 아닙니다.
  git -C "$main" config extensions.worktreeConfig true
  # ┎ 주 체크아웃에만 주 훅 디렉터리를 지정합니다.
  git -C "$main" config --worktree core.hooksPath "$WORK/main-hooks"
  # ┎ 실제 Git worktree 기능으로 다른 브랜치의 연결된 체크아웃을 만듭니다.
  git -C "$main" worktree add -q -b fixture-linked "$WORK/linked"
  # ┎ 연결된 워크트리에만 별도 훅 디렉터리를 지정합니다.
  git -C "$WORK/linked" config --worktree core.hooksPath "$WORK/linked-hooks"
  # ┎ 모든 워크트리가 공유하는 Git 설정을 보존 기준으로 복사합니다.
  cp "$main/.git/config" "$WORK/common-config.saved"
  # ┎ 주 체크아웃 전용 Git 설정도 보존 기준으로 복사합니다.
  cp "$main/.git/config.worktree" "$WORK/main-config.saved"
  # ┎ 이번 초기 연결의 대상과 메타데이터 위치를 연결된 워크트리로 바꿉니다.
  CONSUMER="$WORK/linked"; APP=$CONSUMER; META=$(git -C "$APP" rev-parse --absolute-git-dir)/sobaya
  # ┎ 앱 검사에서 읽을 소비 설정 위치도 연결된 워크트리로 바꿉니다.
  export FIXTURE_ROOT="$CONSUMER"
  # ┎ 연결된 워크트리만 Sobaya에 연결하고 필요한 추적 파일을 준비 커밋으로 고정합니다.
  connect; seal_connection
  # ┎ 공통 Git 설정과 주 체크아웃 전용 설정이 연결 전과 완전히 같아야 합니다.
  same "$main/.git/config" "$WORK/common-config.saved"; same "$main/.git/config.worktree" "$WORK/main-config.saved"
  # ┎ 주 체크아웃에서 해석되는 실제 훅 경로가 원래 주 훅 디렉터리여야 합니다.
  [ "$(git -C "$main" config --get core.hooksPath)" = "$WORK/main-hooks" ] || fail 'linked init changed main hook selection'
  # ┎ 주 체크아웃의 실제 훅 동작을 따로 관찰하도록 기록을 비웁니다.
  : > "$FIXTURE_LOG"
  # ┎ 주 체크아웃에서 실제 빈 커밋이 성공하는지 확인합니다.
  invoke git -C "$main" commit --allow-empty -m main-still-independent; okay
  # ┎ 주 체크아웃에서는 원래 main-hook만 실행되고 Sobaya 린트가 섞이지 않아야 합니다.
  printf 'main-hook\n' > "$WORK/expected-events"; same "$FIXTURE_LOG" "$WORK/expected-events"
  # ┎ 연결된 워크트리의 훅 동작을 따로 관찰하도록 기록을 비웁니다.
  : > "$FIXTURE_LOG"
  # ┎ Sobaya에 연결한 워크트리에서도 실제 빈 커밋이 성공하는지 확인합니다.
  invoke git -C "$APP" commit --allow-empty -m linked-connected; okay
  # ┎ 연결된 워크트리에서는 원래 linked-hook 다음 Sobaya 린트가 실행되어야 합니다.
  printf 'linked-hook\nlint\n' > "$WORK/expected-events"; same "$FIXTURE_LOG" "$WORK/expected-events"
  # ┎ 연결 때문에 주 체크아웃에 승인 상태를 새로 만들지 않아야 합니다.
  [ ! -e "$main/.git/sobaya/state.json" ] || fail 'connection created main approval'
  # ┎ 워크트리 연결과 커밋 검사 중 금지 대역이 호출되지 않았는지 확인합니다.
  assert_no_network
}
# ┎ 사례 7은 두 모드 모두 설치본에서 진단·승인·RED/GREEN·체크포인트·별도 리뷰 호출·최종 gate가 실제로 이어지는지 검증합니다.
installed_modes_execute_approved_cycle() {
  # ┎ 두 모드가 사용할 첫 버전 런타임을 설치합니다.
  install_version "$V1"
  # ┎ 종속 모드와 프로젝트 모드의 전체 개발 주기를 각각 실행합니다.
  for mode in dependency project; do
    # ┎ 현재 실행 모드를 위한 새 소비 디렉터리와 설정 조회 위치를 준비합니다.
    CONSUMER="$WORK/run-$mode"; mkdir "$CONSUMER"; export FIXTURE_ROOT="$CONSUMER"
    # ┎ 실제 Git·Node 앱을 준비하고 연결 설정까지 커밋해 깨끗한 시작 상태를 만듭니다.
    app_fixture "$mode"; connect; seal_connection
    # ┎ 승인할 정확한 시작 커밋을 기록합니다.
    baseline=$(git -C "$APP" rev-parse HEAD)
    # ┎ 셸 워커 대역 정책을 명시한 doctor가 설치본의 Git 메타데이터 없이도 성공해야 합니다.
    runtime_cli doctor --policy "$WORK/policy.json"; okay
    # ┎ 고정된 테스트용 요구·계획을 명시적으로 승인합니다. 실제 사용자 입력에 대한 임의 승인을 뜻하지 않습니다.
    runtime_cli approve; okay
    # ┎ 실제 런타임 loop를 실행하되 구현·리뷰 호출은 공통 셸 대역으로 처리합니다.
    runtime_cli loop --policy "$WORK/policy.json"; okay
    # ┎ loop 출력에 RED와 PASS 표시가 있어야 합니다. 완료 여부는 아래 상태·gate·Git 검사로도 확인합니다.
    contains "$WORK/stdout" RED; contains "$WORK/stdout" PASS
    # ┎ 최종 gate 명령이 실제 앱 검사를 통과해야 합니다.
    runtime_cli gate; okay
    # ┎ 검증이 끝난 실제 결과 커밋을 조회합니다.
    head=$(git -C "$APP" rev-parse HEAD)
    # ┎ 상태 형식 1, 원래 승인 커밋, 구현·리뷰 합계 2회 호출, 완료 상태, 리뷰가 현재 HEAD에 연결됨을 함께 요구합니다.
    jq -e --arg baseline "$baseline" --arg head "$head" '.version==1 and .baseline==$baseline and .calls==2 and .status=="complete" and .review.head==$head' "$META/state.json" >/dev/null || fail 'checkpoint/review/usage continuity failed'
    # ┎ 계획 파일에 installedAdds 항목의 완료 표시가 포함됐는지 확인합니다. 다른 항목의 표시까지 비교하는 단정은 아닙니다.
    contains "$APP/failed-test.md" '[x] installedAdds'
    # ┎ 합쳐 기록한 워커·리뷰 프롬프트에서 정확한 설치본의 공통 개발 계약 경로가 발견돼야 합니다. 각 프롬프트에 모두 들어갔거나 대역이 실제 파일을 읽었다는 증거는 아닙니다.
    contains "$FIXTURE_PROMPTS" "$STORE/runtimes/$V1/runtime/tdd-set/AGENTS.md"
    # ┎ 프롬프트에 실제 앱 지침의 전체 경로도 포함돼야 합니다.
    contains "$FIXTURE_PROMPTS" "$APP/AGENTS.md"
    # ┎ 완료된 앱에 남은 추적·미추적 변경이 없어야 합니다.
    [ -z "$(git -C "$APP" status --porcelain)" ] || fail 'completed app is dirty'
    # ┎ status 조회가 승인·실행·연결 메타데이터의 내용·경로·권한·링크를 바꾸지 않는지 확인합니다.
    snapshot "$META" "$WORK/state.before"; runtime_cli status; okay; snapshot "$META" "$WORK/state.after"; same "$WORK/state.before" "$WORK/state.after"
  done
  # ┎ 두 모드의 실제 개발 주기에서 금지 대역이 호출되지 않았는지 확인합니다.
  assert_no_network
}
# ┎ 사례 8은 lock 신원 불일치 시 다른 설치본으로 우회하지 않고, 워커의 실행 중 pin 변경도 체크포인트 전에 거부하는지 검증합니다.
dispatch_rejects_pin_drift_and_worker_mutation() {
  # ┎ 서로 다른 두 버전을 설치한 뒤 첫 버전에 연결된 종속 모드 앱을 준비합니다.
  install_version "$V1"; install_version "$V2"; app_fixture dependency; connect; seal_connection
  # ┎ 테스트용 입력을 승인하고 그 시점의 커밋을 기록합니다.
  runtime_cli approve; okay; baseline=$(git -C "$APP" rev-parse HEAD)
  # ┎ 정상 lock과 승인 메타데이터를 보존 기준으로 저장합니다.
  cp "$CONSUMER/sobaya.lock" "$WORK/lock.saved"; snapshot "$META" "$WORK/state.before"
  # ┎ lock의 SHA-256만 존재하지 않는 값으로 바꾸어 선택할 설치 신원을 일치하지 않게 만듭니다.
  jq '.runtime.sha256=("0"*64)' "$WORK/lock.saved" > "$CONSUMER/sobaya.lock"
  # ┎ 변조된 lock 상태에서 읽기 전용 status를 호출해도 먼저 설치 신원을 검증해야 합니다.
  runtime_cli status
  # ┎ 다른 설치 버전으로 조용히 우회하여 성공하지 못하도록 실패를 요구합니다.
  [ "$RC" -ne 0 ] || fail 'uninstalled identity fell back to another runtime'
  # ┎ 잘못된 lock을 거부하는 동안 승인 메타데이터가 바뀌지 않았는지 확인합니다.
  snapshot "$META" "$WORK/state.after"; same "$WORK/state.before" "$WORK/state.after"
  # ┎ 다음 워커 변조 사례를 위해 정상 lock을 복구합니다.
  cp "$WORK/lock.saved" "$CONSUMER/sobaya.lock"
  # ┎ 구현 대역이 소스를 고친 후 설정의 버전까지 변조하도록 켭니다.
  export FIXTURE_TAMPER=1
  # ┎ 승인된 한 항목의 실제 step을 실행하여 런타임의 보호 입력 검사를 거칩니다.
  runtime_cli step --policy "$WORK/policy.json"
  # ┎ 워커가 pin을 바꾼 상태로 체크포인트를 통과하지 못하도록 실패를 요구합니다.
  [ "$RC" -ne 0 ] || fail 'worker changed pinned version and passed checkpoint'
  # ┎ 오류가 단순 테스트 실패가 아니라 보호 입력 위반을 나타내는지 확인합니다.
  grep -iq protect "$WORK/stderr" || fail 'pin mutation did not report protected-input rejection'
  # ┎ 변조가 일어난 작업을 새 커밋으로 확정하지 않아야 합니다.
  [ "$(git -C "$APP" rev-parse HEAD)" = "$baseline" ] || fail 'pin mutation was committed'
  # ┎ 기존 승인 커밋과 누적 호출 1회를 유지하고 같은 installedAdds 항목을 미완료 상태로 보존해야 합니다.
  jq -e --arg baseline "$baseline" '.baseline==$baseline and .calls==1 and .active.entry=="installedAdds"' "$META/state.json" >/dev/null || fail 'pin mutation reset or advanced approval'
  # ┎ 검증을 통과하지 않은 계획 항목이 체크되지 않아야 합니다.
  contains "$APP/failed-test.md" '[ ] installedAdds'
  # ┎ 신원 불일치·워커 변조 검사 중 금지 대역이 호출되지 않았는지 확인합니다.
  assert_no_network
}
# ┎ 사례 9는 sync가 이미 검토된 lock의 신원만 설치하고 소비 프로젝트의 설정·내용을 다시 고정하거나 바꾸지 않아야 함을 검증합니다.
sync_uses_reviewed_lock_without_repinning() {
  # ┎ 첫 버전에 연결된 깨끗한 종속 모드 앱을 준비합니다.
  install_version "$V1"; app_fixture dependency; connect; seal_connection
  # ┎ sync 전 소비 디렉터리 전체를 보존 기준으로 기록합니다.
  snapshot "$CONSUMER" "$WORK/consumer.before"
  # ┎ 기존 실행기는 유지하되 설치 대상은 새로운 두 번째 저장소로 바꿉니다.
  original_store=$STORE; STORE="$WORK/second-store"
  # ┎ 기존 안정 실행기로 소비 lock과 첫 버전 아카이브를 읽어 새 저장소에 sync합니다.
  invoke "$original_store/bin/sobaya" sync --root "$CONSUMER" --install-root "$STORE" --archive "$(archive "$V1")"
  # ┎ sync가 성공하고 lock은 첫 버전의 원래 신원 그대로여야 합니다.
  okay; assert_pin "$V1"
  # ┎ 새 저장소에 lock이 지정한 첫 버전 실행기가 실행 가능한 상태로 설치됐는지 확인합니다.
  [ -x "$STORE/runtimes/$V1/runtime/bin/sobaya" ] || fail 'sync did not install the locked runtime'
  # ┎ 성공한 sync가 소비 디렉터리를 변경하지 않았는지 확인합니다.
  snapshot "$CONSUMER" "$WORK/consumer.after"; same "$WORK/consumer.before" "$WORK/consumer.after"
  # ┎ 잘못된 아카이브 사례는 또 다른 비어 있는 설치 저장소에서 시험합니다.
  STORE="$WORK/third-store"
  # ┎ 첫 버전을 고정한 lock에 두 번째 버전 아카이브를 전달합니다.
  invoke "$original_store/bin/sobaya" sync --root "$CONSUMER" --install-root "$STORE" --archive "$(archive "$V2")"
  # ┎ 아카이브 해시 불일치를 코드 2와 hash 진단으로 거부해야 합니다.
  invalid hash
  # ┎ 거부된 아카이브를 첫 버전 설치 경로로 게시하지 않아야 합니다.
  [ ! -e "$STORE/runtimes/$V1" ] || fail 'sync published mismatched archive'
  # ┎ 실패한 sync 역시 소비 디렉터리를 변경하지 않아야 합니다.
  snapshot "$CONSUMER" "$WORK/consumer.after"; same "$WORK/consumer.before" "$WORK/consumer.after"
  # ┎ 두 sync 시도에서 금지 대역이 호출되지 않았는지 확인합니다.
  assert_no_network
}
# ┎ 사례 10은 새 런타임으로 실제 앱 전체 검사·린트를 거친 bump가 설정·lock만 바꾸고 승인·사용량·HEAD는 보존하는지 검증합니다.
bump_validates_candidate_and_preserves_approval() {
  # ┎ 첫 버전에 연결된 종속 모드 앱을 준비합니다.
  install_version "$V1"; app_fixture dependency; connect; seal_connection
  # ┎ 먼저 기존 버전에서 승인부터 완료까지 실제 개발 주기를 끝내어 보존할 승인·리뷰·사용량 상태를 만듭니다.
  runtime_cli approve; okay; runtime_cli loop --policy "$WORK/policy.json"; okay
  # ┎ 소비 설정에 사용자 정의 값을 추가하고 커밋하여 bump가 모르는 설정도 유지해야 하게 합니다.
  jq '.custom={keep:"yes"}' "$CONSUMER/sobaya.json" > "$WORK/config.new"; mv "$WORK/config.new" "$CONSUMER/sobaya.json"; commit_app
  # ┎ 메타데이터와 설정·lock의 변경 전 원본을 기록합니다.
  snapshot "$META" "$WORK/state.before"; cp "$CONSUMER/sobaya.json" "$WORK/config.saved"; cp "$CONSUMER/sobaya.lock" "$WORK/lock.saved"
  # ┎ bump가 자동 커밋을 만들지 않는지 비교할 현재 HEAD를 저장합니다.
  before=$(git -C "$APP" rev-parse HEAD)
  # ┎ bump의 검사 이벤트만 관찰하도록 기록을 비웁니다.
  : > "$FIXTURE_LOG"
  # ┎ 두 번째 버전의 실제 매니페스트·아카이브로 명시적 bump를 요청하고 성공을 요구합니다.
  cli bump --version "$V2" --manifest "$(manifest "$V2")" --archive "$(archive "$V2")"; okay
  # ┎ lock이 두 번째 신원으로 바뀌고 앱 검사에서 두 번째 설정 버전을 관찰했는지 확인합니다.
  assert_pin "$V2"; contains "$FIXTURE_LOG" "suite:$V2"
  # ┎ 계측된 실제 전체 검사 함수가 두 번째 런타임에서 실행됐는지 확인합니다. 설정 문자열만 바뀐 결과로는 통과하지 못합니다.
  contains "$FIXTURE_LOG" "runtime-suite:$V2"
  # ┎ bump 검증 과정에서 선언된 린트도 실행됐는지 확인합니다.
  contains "$FIXTURE_LOG" lint
  # ┎ 설정의 런타임 버전이 새 값이고, 종속 모드와 custom.keep 값이 유지됐는지 확인합니다. 이 단정만으로 나머지 모든 필드의 보존을 증명하지는 않습니다.
  jq -e --arg version "$V2" '.runtime.version==$version and .mode=="dependency" and .custom.keep=="yes"' "$CONSUMER/sobaya.json" >/dev/null || fail 'bump damaged configuration'
  # ┎ 기존 승인·실행·리뷰·연결 메타데이터의 스냅샷은 완전히 같아야 합니다.
  snapshot "$META" "$WORK/state.after"; same "$WORK/state.before" "$WORK/state.after"
  # ┎ bump는 새 커밋을 만들지 않아야 합니다. 승인 보존은 바로 위 메타데이터 비교가 검증합니다.
  [ "$(git -C "$APP" rev-parse HEAD)" = "$before" ] || fail 'bump committed or reapproved automatically'
  # ┎ Git의 스테이지되지 않은 추적 파일 차이에서 변경된 파일 이름을 모읍니다. 스테이지된 변경과 미추적 파일은 이 목록에 포함되지 않습니다.
  git -C "$APP" diff --name-only | LC_ALL=C sort > "$WORK/changed"
  # ┎ 스테이지되지 않은 추적 변경 목록이 sobaya.json과 sobaya.lock 두 개여야 합니다. 스테이지된 변경과 미추적 파일의 부재는 이 비교로 증명하지 않습니다.
  printf 'sobaya.json\nsobaya.lock\n' > "$WORK/expected-changed"; same "$WORK/changed" "$WORK/expected-changed"
  # ┎ 새 pin에서도 기존 승인 상태를 status로 읽을 수 있어야 합니다.
  runtime_cli status; okay
  # ┎ bump 성공과 status 조회 중 금지 대역이 호출되지 않았는지 확인합니다.
  assert_no_network
}
# ┎ 사례 11은 새 버전 검증 실패 시 이전 pin을 복구하고, 진행 중인 항목이 있으면 bump를 거부하며 승인·사용량 상태를 보존하는지 검증합니다.
bump_failure_and_active_entry_keep_previous_pin() {
  # ┎ 첫 버전에 연결된 종속 모드 앱을 준비합니다.
  install_version "$V1"; app_fixture dependency; connect; seal_connection
  # ┎ 테스트용 입력을 승인하여 bump가 보존할 기존 승인 상태를 만듭니다.
  runtime_cli approve; okay
  # ┎ 정상 설정·lock·메타데이터를 실패 복구의 비교 기준으로 보관합니다.
  cp "$CONSUMER/sobaya.json" "$WORK/config.saved"; cp "$CONSUMER/sobaya.lock" "$WORK/lock.saved"; snapshot "$META" "$WORK/state.before"
  # ┎ 전체 테스트 실패와 린트 실패를 별도로 주입합니다.
  for failure in suite lint; do
    # ┎ 각 반복은 먼저 전체 테스트·린트 성공 상태로 초기화합니다.
    export FIXTURE_SUITE=pass FIXTURE_LINT=pass
    # ┎ 이번 반복에서 정한 한 종류의 검사만 실패하도록 설정합니다.
    if [ "$failure" = suite ]; then export FIXTURE_SUITE=fail; else export FIXTURE_LINT=fail; fi
    # ┎ 이번 실패 시도의 검사 이벤트만 관찰하도록 기록을 비웁니다.
    : > "$FIXTURE_LOG"
    # ┎ 두 번째 버전으로 bump를 시도하여 후보 런타임의 실제 검증 실패를 만듭니다.
    cli bump --version "$V2" --manifest "$(manifest "$V2")" --archive "$(archive "$V2")"
    # ┎ 검증 실패를 코드 2와 validation 진단으로 보고하고, 앱 테스트가 후보 버전을 관찰했어야 합니다.
    invalid validation; contains "$FIXTURE_LOG" "suite:$V2"
    # ┎ 실패한 시도에서도 실제 전체 검사 함수가 후보 런타임에서 호출됐는지 확인합니다.
    contains "$FIXTURE_LOG" "runtime-suite:$V2"
    # ┎ 린트 실패 사례는 린트가 실제로 호출됐다는 이벤트까지 요구합니다.
    [ "$failure" != lint ] || contains "$FIXTURE_LOG" lint
    # ┎ 실패 뒤 설정과 lock이 이전 원본으로 정확히 복구돼야 합니다.
    same "$CONSUMER/sobaya.json" "$WORK/config.saved"; same "$CONSUMER/sobaya.lock" "$WORK/lock.saved"
    # ┎ 검증 실패가 승인·누적 호출·진행 기록을 바꾸지 않아야 합니다.
    snapshot "$META" "$WORK/state.after"; same "$WORK/state.before" "$WORK/state.after"
  done
  # ┎ 검사 실패 주입은 해제하고 워커의 pin 변조를 켜서 다음에는 미완료 항목을 만듭니다.
  export FIXTURE_SUITE=pass FIXTURE_LINT=pass FIXTURE_TAMPER=1
  # ┎ 실제 한 항목 실행으로 보호 입력 위반 상태를 생성합니다.
  runtime_cli step --policy "$WORK/policy.json"
  # ┎ 변조 시도가 통과하지 않고 미완료 상태를 남길 것을 요구합니다.
  [ "$RC" -ne 0 ] || fail 'expected a protected-input handoff'
  # ┎ 테스트가 직접 원래 설정을 복구하여 이후 bump 거부 원인이 pin 불일치보다 진행 중 항목에 있도록 합니다.
  cp "$WORK/config.saved" "$CONSUMER/sobaya.json"
  # ┎ 미완료 항목이 포함된 현재 메타데이터를 보존 기준으로 기록합니다.
  snapshot "$META" "$WORK/active.before"
  # ┎ 활성 항목이 있는 상태에서 두 번째 버전 bump를 시도합니다.
  cli bump --version "$V2" --manifest "$(manifest "$V2")" --archive "$(archive "$V2")"
  # ┎ 진행 중 항목을 이유로 코드 2, 빈 표준 출력, active 진단으로 거부해야 합니다.
  invalid active
  # ┎ 거부 뒤 설정과 lock이 원래 값 그대로여야 합니다.
  same "$CONSUMER/sobaya.json" "$WORK/config.saved"; same "$CONSUMER/sobaya.lock" "$WORK/lock.saved"
  # ┎ 미완료 항목과 사용량을 포함한 메타데이터를 바꾸거나 재승인하지 않아야 합니다.
  snapshot "$META" "$WORK/active.after"; same "$WORK/active.before" "$WORK/active.after"
  # ┎ 실패 뒤에도 status로 보존된 상태를 조회할 수 있어야 합니다.
  runtime_cli status; okay
  # ┎ 검증 실패 복구와 활성 항목 거부 과정에서 금지 대역이 호출되지 않았는지 확인합니다.
  assert_no_network
}
# ┎ 사례 12는 연결된 두 앱이 후보 설정을 관찰하고 후보 런타임의 검사 호출이 있었는지, 두 번째 앱의 실패가 프로젝트 pin 변경을 거부하게 하는지 검증합니다.
project_bump_checks_every_connected_app() {
  # ┎ 첫 버전에 연결된 프로젝트 모드 워크스페이스와 첫 앱을 준비합니다.
  install_version "$V1"; app_fixture project; connect; seal_connection
  # ┎ 첫 앱 경로를 저장하고 같은 워크스페이스의 두 번째 앱 경로를 정합니다.
  first=$APP; second="$CONSUMER/apps/second"
  # ┎ 실제 로컬 Git clone으로 두 번째 앱을 만듭니다. 하드 링크 공유를 끄며 외부 네트워크는 쓰지 않습니다.
  git clone -q --no-hardlinks "$first" "$second"
  # ┎ 두 번째 앱의 준비 커밋 작성자 정보를 지정합니다.
  git -C "$second" config user.name Fixture; git -C "$second" config user.email fixture@example.invalid
  # ┎ 두 번째 앱만의 검사 실행과 실패를 구분할 Node 테스트를 추가합니다.
  cat >> "$second/suite.test.js" <<'SECOND_TEST'
// ┎ 두 번째 앱 검사가 실행됐음을 기록하고 FIXTURE_SECOND가 fail이면 실제 Node 단정 실패를 발생시킵니다.
test('secondAppGuard', () => { fs.appendFileSync(process.env.FIXTURE_LOG, 'second-app-suite\n'); assert.notEqual(process.env.FIXTURE_SECOND, 'fail'); });
SECOND_TEST
  # ┎ 대상 앱을 두 번째 앱으로 바꾸고 추가한 테스트를 준비 커밋에 담습니다.
  APP=$second; commit_app
  # ┎ 같은 프로젝트·같은 버전에 두 번째 앱을 명시적으로 연결하고 성공을 요구합니다.
  cli init --mode project --version "$V1" --app "$second"; okay
  # ┎ 두 번째 앱에 생긴 연결 파일을 준비 커밋으로 고정합니다.
  commit_app
  # ┎ 워크스페이스 bump가 자동 커밋하지 않는지 비교할 HEAD를 저장합니다.
  before=$(git -C "$CONSUMER" rev-parse HEAD)
  # ┎ 두 앱의 후보 검증 이벤트만 관찰하도록 기록을 비웁니다.
  : > "$FIXTURE_LOG"
  # ┎ 워크스페이스를 두 번째 버전으로 bump하고 성공을 요구합니다.
  cli bump --version "$V2" --manifest "$(manifest "$V2")" --archive "$(archive "$V2")"; okay
  # ┎ lock이 후보 버전으로 바뀌고 후보 런타임의 전체 검사 호출이 최소 한 번 있으며, 두 번째 앱의 전용 검사도 실행됐어야 합니다. 이 이벤트만으로 각 앱의 실행기 신원을 따로 연결하지는 않습니다.
  assert_pin "$V2"; contains "$FIXTURE_LOG" "runtime-suite:$V2"; contains "$FIXTURE_LOG" second-app-suite
  # ┎ 첫 앱과 두 번째 앱 각각에서 설정의 후보 버전을 읽은 이벤트가 존재해야 하므로 한 앱만 검사해서는 통과하지 못합니다.
  contains "$FIXTURE_LOG" "suite-app:$first:$V2"; contains "$FIXTURE_LOG" "suite-app:$second:$V2"
  # ┎ 성공한 프로젝트 bump도 워크스페이스 HEAD를 자동으로 바꾸지 않아야 합니다.
  [ "$(git -C "$CONSUMER" rev-parse HEAD)" = "$before" ] || fail 'project bump committed automatically'
  # ┎ 성공한 두 번째 버전 설정과 lock을 이후 실패 복구의 비교 기준으로 보관합니다.
  cp "$CONSUMER/sobaya.json" "$WORK/config.saved"; cp "$CONSUMER/sobaya.lock" "$WORK/lock.saved"
  # ┎ 테스트 준비 단계에서 성공한 설정·lock을 워크스페이스 인덱스에 올립니다.
  git -C "$CONSUMER" add sobaya.json sobaya.lock
  # ┎ 성공한 bump를 검토 후 커밋한 상황을 흉내 내는 준비 커밋을 만듭니다. 훅은 우회하며 실제 사람 승인을 새로 주장하지 않습니다.
  git -C "$CONSUMER" -c user.name=Fixture -c user.email=fixture@example.invalid -c core.hooksPath=/dev/null commit -qm reviewed-bump
  # ┎ 두 번째 앱의 전용 테스트만 실패하도록 설정합니다.
  export FIXTURE_SECOND=fail
  # ┎ 실패할 되돌림 시도의 이벤트만 관찰하도록 기록을 비웁니다.
  : > "$FIXTURE_LOG"
  # ┎ 첫 버전으로 되돌리는 bump를 요청하고, 아래에서 두 번째 앱의 실행과 실패가 전체 변경을 막는지 확인합니다.
  cli bump --version "$V1" --manifest "$(manifest "$V1")" --archive "$(archive "$V1")"
  # ┎ 두 번째 앱 검사가 실행되고 그 실패 때문에 validation 진단으로 되돌림을 거부해야 합니다.
  invalid validation; contains "$FIXTURE_LOG" second-app-suite
  # ┎ 거부 뒤에도 성공적으로 고정했던 두 번째 버전의 설정·lock을 정확히 보존해야 합니다.
  same "$CONSUMER/sobaya.json" "$WORK/config.saved"; same "$CONSUMER/sobaya.lock" "$WORK/lock.saved"
  # ┎ 프로젝트 bump 성공·실패 과정에서 금지 대역이 호출되지 않았는지 확인합니다.
  assert_no_network
}
# ┎ 하위 프로세스가 __case로 호출되면 전용 준비 자료를 만든 뒤 지정한 한 사례만 실행하고 종료합니다.
if [ "${1:-}" = __case ]; then setup; "$2"; exit; fi
# ┎ 전체 실행에서 실패한 사례 수를 0으로 시작합니다.
failures=0
# ┎ 위 12개 행동 사례를 정해진 순서로 실행합니다. 각 사례의 구체적인 준비와 기대값은 해당 함수 위 설명에 있습니다.
for name in install_pins_real_release_and_transport install_rejects_identity_and_unsafe_payload install_preserves_existing_paths_and_failed_downloads init_connects_both_modes_without_rewriting_contracts connected_hooks_preserve_original_behavior connection_keeps_linked_worktree_hooks_isolated installed_modes_execute_approved_cycle dispatch_rejects_pin_drift_and_worker_mutation sync_uses_reviewed_lock_without_repinning bump_validates_candidate_and_preserves_approval bump_failure_and_active_entry_keep_previous_pin project_bump_checks_every_connected_app; do
  # ┎ 각 사례를 새 Bash 프로세스로 실행하여 상태를 분리하고, 결과를 표시한 뒤 실패 수를 누적합니다.
  if /bin/bash "$0" __case "$name"; then printf 'PASS: %s\n' "$name"; else printf 'FAIL: %s\n' "$name"; failures=$((failures+1)); fi
done
# ┎ 12개 사례 중 하나라도 실패하면 전체 테스트 파일도 실패로 종료합니다.
[ "$failures" -eq 0 ]
````
