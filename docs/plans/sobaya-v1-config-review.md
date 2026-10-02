# Sobaya v1 첫 설정 검사 테스트 검토본

검토용 — 설명 주석은 실행 코드에 포함되지 않음

이 네 항목은 2026-10-02 사람이 승인한 Bash 테스트입니다. 승인된 실행용 원본은
[`draft-config-tests.sh`](../../brain/plans/04-versioned-modes/draft-config-tests.sh)이며,
`bin/sobaya config check --root PATH`를 검사합니다. 전체 v1 구현이나
나머지 단계의 테스트까지 승인하는 문서는 아닙니다.

## 이번에 확인할 동작

| 항목 | 기대 동작 |
|---|---|
| 명시적 모드 선택 | project/dependency와 0.9.0/1.0.0/1.0.0-rc.1을 지정한 작업 공간에서 읽음 |
| 파일·JSON 오류 | 설정 누락이나 잘못된 JSON이면 모드를 추측하지 않고 거절 |
| 설정 필드 오류 | 형식 버전·모드·실행기 버전의 누락, 잘못된 타입, 비고정 버전을 거절 |
| lock 검증 | lock 누락·형식 오류·버전 불일치·잘못된 커밋/파일 해시를 거절 |

성공은 종료 코드 0과 JSON 객체 하나, 입력 오류는 종료 코드 2와 문제 필드 또는
파일 이름을 담은 stderr 진단입니다. 출력 JSON은 `config_version`,
`mode`, 그리고 lock의 `runtime` 객체입니다. 오류 때 stdout은 비어 있어야 합니다.
각 사례에서 작업 공간의 경로·파일 내용이 보존되는지 확인하며 Git 훅 설정과
`.git/sobaya`의 가짜 상태, 기존 훅의 실행 권한도 포함합니다. 파일 수정 시각이나 모든 네트워크 경로의
차단까지 증명하는 테스트는 아닙니다.

해시 값은 가짜 픽스처입니다. 이 명령은 설치 전 로컬 설정 검사이며, 실제 커밋의
존재나 다운로드 파일의 무결성을 증명하지 않습니다. 아카이브 검증·네트워크와
워커 호출 제한·모드 연결·bump·복귀는 다음 테스트 묶음에서 다룹니다. 알 수 없는
추가 키, 중복 JSON 키, 심링크의 정책도 이 초안으로 확정하지 않습니다.

## 검사 상태

- 승인 전 기준에는 `bin/sobaya`가 없어 실행 결과가 `NOT PROBED`였습니다.
- Bash 3.2 문법 검사와 설명 줄을 제외한 원본 대조가 통과했습니다.
- 무조건 성공하는 `/usr/bin/true`를 대상에 넣은 음성 대조에서 네 항목 모두 이를 거절했습니다.
- 명령 부재를 정상적인 RED나 오류 사례의 통과로 세지 않습니다.
- 승인된 원본을 `tests/test-config.sh`에 그대로 복사했습니다. 원본의 DRAFT 주석은 당시 기록으로 보존합니다.
- 네 항목을 순서대로 실제 실패 확인 → 구현 → 기존 전체 스위트 검증까지 마쳤습니다.
- 네 항목이 포함된 전체 `tests/run.sh`도 통과했습니다. 상세 기록은
  [검증 기록](../../brain/plans/04-versioned-modes/config-validation.md)에 있습니다.

승인된 실행용 원본 SHA-256:
`522bfee85eca9cf1228797491fd60cb625795b5385f9cd6244633739eca92f64`

합의한 아키텍처를 다시 승인받는 문서가 아닙니다. 승인된 범위는 위 명령의
입출력 규약, lock의 필드 구조, 아래 네 항목의 실행용 코드와 공통 준비 코드입니다.
하네스 루트용 Bash 초안이므로 앱용 `approve.sh`로 승인했다고 꾸미지 않습니다.
검토 표시는 사용자 요청에 따라 `┎`으로 바꿨으며, 설명 줄을 뺀 코드는 승인 당시와 같습니다.

## 공통 준비와 전체 테스트 코드

Bash의 주석 문법에 맞춰 `# ┎ 설명`을 해당 코드 바로 위에 표시합니다. 공유 준비 코드는 한 번 설명하며,
각 항목은 이 준비 코드를 사용합니다. 원본의 모든 줄을 그대로 포함합니다.

```bash
#!/bin/bash
# DRAFT: proposed root-harness tests; not part of the approved suite.
# ┎ 테스트 중 명령 실패나 정의되지 않은 변수 사용을 만나면 즉시 중단한다.
set -eu
# ┎ 파이프라인 중간 명령의 실패도 테스트 실패로 처리한다.
set -o pipefail

# ┎ 테스트 준비에 필요한 jq와 Git이 없으면 검사 불가로 종료한다.
for tool in jq git; do command -v "$tool" >/dev/null || { printf "NOT PROBED: missing %s\n" "$tool" >&2; exit 2; }; done
# ┎ 초안을 나중에 정식 테스트 위치로 옮겨도 같은 저장소 루트를 찾도록 Git에 확인한다.
ROOT=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
# ┎ 기본 검증 대상은 앞으로 만들 bin/sobaya이고, 별도 경로를 지정해 시험할 수도 있다.
CLI=${SOBAYA_CLI:-"$ROOT/bin/sobaya"}
# ┎ 실행 위치에 따라 다른 파일이 선택되지 않도록 검증 대상은 절대 경로만 받는다.
case "$CLI" in /*) ;; *) printf "NOT PROBED: SOBAYA_CLI must be absolute\n" >&2; exit 2 ;; esac
# ┎ 아직 명령이 없으면 행위 실패로 세지 않고 검사 불가로 종료한다.
[ -x "$CLI" ] || { printf "NOT PROBED: future CLI is absent: %s\n" "$CLI" >&2; exit 2; }
# ┎ 하위 테스트 프로세스에서도 동일한 실행 파일을 검사하도록 경로를 전달한다.
export SOBAYA_CLI="$CLI"
# ┎ 임시 Git 저장소 준비가 개인·시스템 Git 설정에 좌우되지 않도록 격리한다.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

# ┎ 원하는 결과와 다르면 원인을 출력하고 해당 테스트를 실패시킨다.
fail() { printf "FAIL: %s\n" "$*" >&2; exit 1; }
# ┎ 작업 공간의 모든 경로와 파일 내용 체크섬을 기록하는 공통 도구다.
snapshot() {
  # ┎ 입력 작업 공간으로 이동해서 경로 목록과 파일 내용 체크섬을 각각 정렬해 기록한다.
  (cd "$APP"; find . -print | LC_ALL=C sort; find . -type f -exec cksum {} \; | LC_ALL=C sort) > "$1"
}
# ┎ 각 테스트 전용 임시 폴더와 검사에 사용할 가짜 해시 값을 준비한다.
setup() {
  # ┎ 다른 작업과 충돌하지 않는 임시 폴더를 만든다.
  WORK=$(mktemp -d "${TMPDIR:-/tmp}/sobaya-config-draft.XXXXXX")
  # ┎ 테스트 종료 시 이 테스트가 만든 임시 폴더만 지운다.
  trap 'rm -rf "$WORK"' EXIT
  # ┎ 공백과 작은따옴표가 들어간 작업 공간 경로도 처리하는지 검사한다.
  APP="$WORK/workspace's path"
  # ┎ 실제 존재 확인을 요구하지 않는 40자리 커밋 형식의 가짜 값이다.
  COMMIT=0123456789abcdef0123456789abcdef01234567
  # ┎ 실제 다운로드 파일이 아닌 64자리 해시 형식의 가짜 값이다.
  SHA256=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
}
# ┎ 지정한 모드·버전과 그에 일치하는 lock이 있는 작업 공간을 새로 준비한다.
fixture() {
  # ┎ 앞선 하위 사례의 임시 작업 공간을 제거해 사례 사이 영향을 없앤다.
  rm -rf "$APP"
  # ┎ 보존 여부를 확인할 훅 폴더를 만든다.
  mkdir -p "$APP/.githooks"
  # ┎ 실제 Git 저장소를 준비하되 외부 네트워크에는 연결하지 않는다.
  git -C "$APP" init -q
  # ┎ 소비 프로젝트가 이미 별도 Git 훅을 사용하는 상황을 만든다.
  git -C "$APP" config core.hooksPath .githooks
  # ┎ 기존 소바야 상태가 저장되는 위치를 준비한다.
  mkdir -p "$APP/.git/sobaya"
  # ┎ 기존 지침 파일이 검사 과정에서 바뀌지 않는지 확인할 내용을 넣는다.
  printf "Existing consumer instructions\n" > "$APP/AGENTS.md"
  # ┎ 기존 훅이 교체되지 않는지 확인할 내용을 넣는다.
  printf "#!/bin/sh\nexit 0\n" > "$APP/.githooks/pre-commit"
  # ┎ 기존 훅을 실제 실행 가능한 상태로 만들어 실행 권한 보존도 검사한다.
  chmod 755 "$APP/.githooks/pre-commit"
  # ┎ 기존 승인 상태의 내용 보존을 확인할 가짜 기록을 넣는다. 실제 루프는 실행하지 않는다.
  printf '{"version":1,"calls":7,"active":null}\n' > "$APP/.git/sobaya/state.json"
  # ┎ 지정한 모드와 출시 버전으로 사람이 관리할 설정 파일을 만든다.
  jq -n --arg mode "$1" --arg version "$2" '{config_version:1,mode:$mode,runtime:{version:$version}}' > "$APP/sobaya.json"
  # ┎ 설정과 같은 버전 및 가짜 커밋·배포 해시로 lock을 만든다.
  jq -n --arg version "$2" --arg commit "$COMMIT" --arg sha256 "$SHA256" '{lock_version:1,runtime:{version:$version,commit:$commit,sha256:$sha256}}' > "$APP/sobaya.lock"
}
# ┎ 설정이나 lock에 특정 오류를 넣을 때 사용하는 공통 도구다.
rewrite() {
  # ┎ 지정한 파일에 jq 변환을 적용한 결과를 임시 파일로 저장한다.
  jq "$2" "$APP/$1" > "$WORK/changed.json"
  # ┎ 검사 전에 해당 파일을 변환 결과로 교체한다.
  mv "$WORK/changed.json" "$APP/$1"
}
# ┎ 검사 명령을 실행하고 결과와 작업 공간 보존 여부를 함께 확인한다.
invoke() {
  # ┎ 실행 전 경로와 파일 내용을 기록한다. Git 로컬 상태와 훅 설정도 포함된다.
  snapshot "$WORK/before"
  # ┎ 작업 공간 밖에서 명령을 실행해 현재 디렉터리가 아닌 --root의 설정을 읽게 한다.
  if (cd "$WORK"; "$CLI" config check --root "$APP") > "$WORK/stdout" 2> "$WORK/stderr"; then RC=0; else RC=$?; fi
  # ┎ 실행 후 같은 범위의 경로와 파일 내용을 기록한다.
  snapshot "$WORK/after"
  # ┎ 성공·실패 어느 경우에도 파일 생성·삭제나 내용 변경이 생기면 실패시킨다.
  cmp -s "$WORK/before" "$WORK/after" || fail "config check changed workspace content or paths"
  # ┎ 설정 검사 때문에 기존 훅의 실행 권한이 사라지면 실패시킨다.
  [ -x "$APP/.githooks/pre-commit" ] || fail "config check disabled existing hook"
}
# ┎ 유효한 설정일 때 성공 상태와 선택 결과를 확인한다.
expect_valid() {
  # ┎ 설정 검사 명령을 실행한다.
  invoke
  # ┎ 유효한 설정은 종료 코드 0으로 성공해야 한다.
  [ "$RC" -eq 0 ] || fail "valid config returned $RC"
  # ┎ 성공 결과에 오류 출력이 섞여 있으면 실패시킨다.
  [ ! -s "$WORK/stderr" ] || fail "valid config wrote stderr"
  # ┎ 기대 결과는 설정의 형식·모드와 lock의 버전·커밋·해시를 합친 JSON 객체다.
  expected=$(jq -n --slurpfile config "$APP/sobaya.json" --slurpfile lock "$APP/sobaya.lock" '{config_version:$config[0].config_version,mode:$config[0].mode,runtime:$lock[0].runtime}')
  # ┎ 출력 전체가 정확히 JSON 객체 하나이고 기대 결과와 같아야 한다.
  jq -e -s --argjson expected "$expected" 'length == 1 and .[0] == $expected' "$WORK/stdout" >/dev/null || fail "wrong selected configuration"
}
# ┎ 잘못된 설정일 때 오류 상태와 진단이 나오는지 확인한다.
expect_invalid() {
  # ┎ 잘못된 입력으로 검사 명령을 실행한다.
  invoke
  # ┎ 입력 검증 오류는 종료 코드 2로 보고하도록 제안한다.
  [ "$RC" -eq 2 ] || fail "invalid config returned $RC instead of 2"
  # ┎ 오류일 때 성공 결과처럼 보이는 JSON이나 다른 내용을 표준 출력에 내지 않아야 한다.
  [ ! -s "$WORK/stdout" ] || fail "invalid config wrote stdout"
  # ┎ 오류의 대상 필드나 파일 이름을 진단에 포함해야 한다.
  grep -Fq -- "$1" "$WORK/stderr" || fail "diagnostic must identify $1"
}

# ┎ 첫 항목: 두 모드와 고정 버전·시험 버전의 정상 선택을 검증한다.
config_selects_explicit_mode() {
  # ┎ 프로젝트 모드와 종속 모드를 각각 새 작업 공간에서 확인한다.
  for mode in project dependency; do
    # ┎ 선택한 모드와 1.0.0 버전의 설정·lock을 준비한다.
    fixture "$mode" 1.0.0
    # ┎ 현재 디렉터리와 무관하게 지정한 모드·버전을 정확히 반환해야 한다.
    expect_valid
  done
  # ┎ 복귀 기준인 0.9.0과 앞으로 시험할 1.0.0-rc.1도 고정 버전으로 받을 수 있어야 한다.
  for version in 0.9.0 1.0.0-rc.1; do
    # ┎ 각 버전을 사용하는 종속 모드 설정을 준비한다.
    fixture dependency "$version"
    # ┎ 입력 버전을 임의로 최신 버전으로 바꾸지 않고 그대로 반환해야 한다.
    expect_valid
  done
}

# ┎ 두 번째 항목: 설정 파일 자체가 없거나 JSON 구조가 잘못되면 거절한다.
config_rejects_missing_or_malformed_input() {
  # ┎ 기준이 되는 정상 종속 모드 설정을 만든다.
  fixture dependency 1.0.0
  # ┎ 폴더 구조만 보면 프로젝트 모드처럼 보이는 상황을 만든다.
  mkdir -p "$APP/apps" "$APP/brain"
  # ┎ 모드를 지정한 설정 파일을 제거한다.
  rm "$APP/sobaya.json"
  # ┎ 폴더 이름으로 모드를 추측하지 않고 설정 파일이 없다고 보고해야 한다.
  expect_invalid sobaya.json
  # ┎ 빈 파일·깨진 JSON·배열·null·불리언도 설정 객체로 인정하지 않는다.
  for text in '' '{' '[]' 'null' 'true'; do
    # ┎ 각 사례를 정상 설정에서 독립적으로 시작한다.
    fixture dependency 1.0.0
    # ┎ 설정 파일을 해당 잘못된 내용으로 바꾼다.
    printf "%s" "$text" > "$APP/sobaya.json"
    # ┎ 잘못된 설정 파일을 진단하고 종료 코드 2로 거절해야 한다.
    expect_invalid sobaya.json
  done
  # ┎ 정상 설정 파일을 준비해 JSON 객체 두 개를 이어 붙이는 사례를 만든다.
  fixture dependency 1.0.0
  # ┎ 각각은 유효하지만 전체로는 JSON 문서 하나가 아닌 입력을 만든다.
  cat "$APP/sobaya.json" "$APP/sobaya.json" > "$WORK/two.json"
  # ┎ 설정 파일을 두 문서가 이어진 입력으로 교체한다.
  mv "$WORK/two.json" "$APP/sobaya.json"
  # ┎ 첫 객체나 마지막 객체를 임의로 골라 성공시키지 않고 파일 오류를 보고해야 한다.
  expect_invalid sobaya.json
}

# ┎ 세 번째 항목: 설정 필드의 누락·오류와 고정되지 않은 버전을 거절한다.
config_rejects_invalid_fields() {
  # ┎ 설정 형식 버전은 지원하는 숫자 1이어야 한다.
  for change in 'del(.config_version)' '.config_version = 2' '.config_version = "1"'; do
    # ┎ 정상 설정을 준비한다.
    fixture dependency 1.0.0
    # ┎ 설정 형식 버전에 해당 오류를 넣는다.
    rewrite sobaya.json "$change"
    # ┎ 지원하지 않거나 누락된 config_version을 진단해야 한다.
    expect_invalid config_version
  done
  # ┎ 모드는 명시적으로 선택한 두 문자열 중 하나여야 한다.
  for change in 'del(.mode)' '.mode = "automatic"' '.mode = 1'; do
    # ┎ 정상 설정을 준비한다.
    fixture dependency 1.0.0
    # ┎ 모드를 없애거나 허용하지 않은 값으로 바꾼다.
    rewrite sobaya.json "$change"
    # ┎ 모드 오류를 진단해야 한다.
    expect_invalid mode
  done
  # ┎ 실행기 객체와 출시 버전은 필수이며 출시 버전은 문자열이어야 한다.
  for change in 'del(.runtime)' '.runtime = []' 'del(.runtime.version)' '.runtime.version = 1'; do
    # ┎ 정상 설정을 준비한다.
    fixture dependency 1.0.0
    # ┎ 실행기 설정에 해당 구조 오류를 넣는다.
    rewrite sobaya.json "$change"
    # ┎ runtime 필드의 오류를 진단해야 한다.
    expect_invalid runtime
  done
  # ┎ 빈 값·브랜치·최신 별칭·범위·v 접두사·잘못된 숫자 형식은 고정 출시 버전으로 받지 않는다.
  for version in "" main latest "^1.0.0" v1.0.0 01.0.0; do
    # ┎ 해당 버전을 설정과 lock에 같이 넣어 단순 불일치 때문이 아닌 형식 오류를 검사한다.
    fixture dependency "$version"
    # ┎ runtime.version 오류를 진단해야 한다.
    expect_invalid runtime.version
  done
}

# ┎ 네 번째 항목: lock의 존재·형식·버전 일치·커밋과 해시 길이를 검증한다.
lock_requires_exact_matching_runtime() {
  # ┎ 정상 설정과 lock을 준비한다.
  fixture dependency 1.0.0
  # ┎ 도구가 작성할 lock 파일을 제거한다.
  rm "$APP/sobaya.lock"
  # ┎ lock 없이 준비가 완료됐다고 처리하지 않아야 한다.
  expect_invalid sobaya.lock
  # ┎ 깨진 JSON과 배열은 lock으로 인정하지 않는다.
  for text in '{' '[]'; do
    # ┎ 정상 설정과 lock을 준비한다.
    fixture dependency 1.0.0
    # ┎ lock을 잘못된 내용으로 교체한다.
    printf "%s" "$text" > "$APP/sobaya.lock"
    # ┎ lock 파일 오류를 진단해야 한다.
    expect_invalid sobaya.lock
  done
  # ┎ 정상 lock을 준비한다.
  fixture dependency 1.0.0
  # ┎ 유효한 lock 객체 두 개를 이어 붙여 단일 JSON 문서가 아닌 입력을 만든다.
  cat "$APP/sobaya.lock" "$APP/sobaya.lock" > "$WORK/two.json"
  # ┎ lock을 두 문서가 이어진 입력으로 교체한다.
  mv "$WORK/two.json" "$APP/sobaya.lock"
  # ┎ 객체 하나를 임의로 골라 성공시키지 않아야 한다.
  expect_invalid sobaya.lock
  # ┎ lock 형식 버전은 지원하는 숫자 1이어야 한다.
  for change in 'del(.lock_version)' '.lock_version = 2' '.lock_version = "1"'; do
    # ┎ 정상 설정과 lock을 준비한다.
    fixture dependency 1.0.0
    # ┎ lock 형식 버전에 해당 오류를 넣는다.
    rewrite sobaya.lock "$change"
    # ┎ lock_version 오류를 진단해야 한다.
    expect_invalid lock_version
  done
  # ┎ 설정과 lock에서 선택한 출시 버전이 달라지는 경우를 준비한다.
  fixture dependency 1.0.0
  # ┎ lock만 다른 출시 버전으로 바꾼다.
  rewrite sobaya.lock '.runtime.version = "1.0.1"'
  # ┎ runtime.version 불일치를 진단해야 한다.
  expect_invalid runtime.version
  # ┎ lock의 실행기 객체와 버전 필드도 필수다.
  for change in 'del(.runtime)' '.runtime = []' 'del(.runtime.version)'; do
    # ┎ 정상 설정과 lock을 준비한다.
    fixture dependency 1.0.0
    # ┎ lock의 실행기 구조에 해당 오류를 넣는다.
    rewrite sobaya.lock "$change"
    # ┎ lock의 runtime 오류를 진단해야 한다.
    expect_invalid runtime
  done
  # ┎ 커밋 누락·축약 해시·브랜치 이름·길이만 맞는 비16진수 값을 거절한다.
  for change in 'del(.runtime.commit)' '.runtime.commit = "0123456"' '.runtime.commit = "main"' '.runtime.commit = ("g" * 40)'; do
    # ┎ 정상 설정과 lock을 준비한다.
    fixture dependency 1.0.0
    # ┎ 커밋에 해당 오류를 넣는다.
    rewrite sobaya.lock "$change"
    # ┎ runtime.commit 오류를 진단해야 한다.
    expect_invalid runtime.commit
  done
  # ┎ 파일 해시의 누락·짧은 값·길이만 맞는 비16진수 값을 거절한다.
  for change in 'del(.runtime.sha256)' '.runtime.sha256 = "01234567"' '.runtime.sha256 = ("g" * 64)'; do
    # ┎ 정상 설정과 lock을 준비한다.
    fixture dependency 1.0.0
    # ┎ 배포 파일 해시에 해당 오류를 넣는다.
    rewrite sobaya.lock "$change"
    # ┎ runtime.sha256 오류를 진단해야 한다.
    expect_invalid runtime.sha256
  done
}

# ┎ 개별 항목을 하위 프로세스로 실행할 때는 독립된 임시 폴더를 준비한다.
if [ "${1:-}" = __case ]; then
  # ┎ 하위 프로세스의 임시 폴더와 가짜 해시를 준비한다.
  setup
  # ┎ 지정한 테스트 함수 하나를 실행한다. 실패하면 set -e로 이 프로세스가 종료된다.
  "$2"
  # ┎ 해당 항목이 끝나면 정리 후 종료한다.
  exit
fi
# ┎ 전체 결과를 집계할 변수를 준비한다.
failures=0
# ┎ 초안의 네 항목을 순서대로 실행한다.
for name in config_selects_explicit_mode config_rejects_missing_or_malformed_input config_rejects_invalid_fields lock_requires_exact_matching_runtime; do
  # ┎ 각 항목을 Bash 3.2 하위 프로세스로 실행해 이전 항목의 상태와 분리한다.
  if /bin/bash "$0" __case "$name"; then
    # ┎ 해당 항목의 모든 검증이 끝났을 때만 통과로 표시한다.
    printf "PASS: %s\n" "$name"
  else
    # ┎ 실패한 항목을 표시한다.
    printf "FAIL: %s\n" "$name"
    # ┎ 실패 횟수를 하나 늘린다.
    failures=$((failures + 1))
  fi
done
# ┎ 한 항목이라도 실패하면 전체 초안 실행을 실패로 끝낸다.
[ "$failures" -eq 0 ]
```
