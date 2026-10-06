# Sobaya v1 배포 묶음 테스트 검토본

검토용 — 설명 주석은 실행 코드에 포함되지 않음

설치 시 기록할 실제 커밋·배포 파일 해시를 만들기 위한 배포 묶음 생성 단계입니다. 2026-10-02 사람이 아래 네 테스트와 공통 준비 코드를 승인해 구현했습니다. 승인 원문은 그대로 `tests/test-release.sh`에 옮겼으며 설명 주석은 이 검토본에만 있습니다.

## 승인한 명령과 산출물

```sh
bash scripts/package-release.sh \
  --source /path/to/sobaya \
  --version 1.0.0-rc.1 \
  --commit <40자리-커밋> \
  --output /path/to/new-release-directory
```

- 원본은 명시한 로컬 Git 저장소의 루트입니다. 전체 커밋 해시만 받으며 로컬 `v<version>` 태그가 같은 커밋을 가리켜야 합니다. 경량·주석형 태그를 모두 해석합니다.
- 버전은 앞 단계와 같은 정확한 출시 버전입니다. `v` 접두사·브랜치·범위·경로 문자열은 받지 않습니다.
- 원본 밖의 새 출력 디렉터리에 `sobaya-<version>.tar.gz`, `sobaya-<version>.json`을 만듭니다. 이미 존재하는 빈 폴더·파일·심링크도 덮어쓰지 않습니다.
- 성공은 종료 코드 0, stderr 없음, stdout에 메타데이터 JSON 객체 하나입니다. 입력 오류는 종료 코드 2, stdout 없음, 원인을 담은 stderr입니다. 검증한 잘못된 입력에서는 새 출력 경로도 생기지 않아야 합니다.
- 압축 내부 공통 경로는 `sobaya/`입니다. 지정 커밋의 파일 내용과 실행 권한을 유지합니다. 미커밋 변경·미추적 파일·Git의 export-ignore/export-subst 속성으로 배포 내용이 달라지면 안 됩니다.

메타데이터 구조:

```json
{
  "manifest_version": 1,
  "artifact": "sobaya-1.0.0-rc.1.tar.gz",
  "runtime": {
    "version": "1.0.0-rc.1",
    "commit": "<실제 40자리 커밋>",
    "sha256": "<완성된 압축 파일의 실제 SHA-256>"
  }
}
```

해시는 압축 파일 밖의 JSON에 기록합니다. `runtime` 구조는 기존 lock과 같으므로 다음 설치 단계에서 검증한 값을 사용할 수 있습니다. 이번 도구는 소비 프로젝트의 lock을 생성하거나 갱신하지 않습니다.

## 이번 네 항목

| 항목 | 검토할 기대값 |
|---|---|
| 묶음과 메타데이터 | 허용 파일 목록·커밋 원문·실행 권한·실제 압축 해시가 일치하고 압축을 푼 CLI로 설정 검사가 동작 |
| 반복 생성과 원본 선택 | 같은 도구·커밋이면 동일한 바이트. 미커밋 변경, 태그 종류, 내보내기 속성의 영향 차단 |
| 잘못된 원본 거절 | 비고정 버전·축약/없는 커밋·없는/다른 태그·잘못된 원본 경로·필수 파일 누락·선택된 심링크/서브모듈 거절 |
| 기존 상태 보존 | 기존 출력과 연결 대상 보존. 원본 파일·권한·Git 설정·훅·가짜 승인 상태 보존. 원본 내부 출력 거절 |

배포할 파일 범위는 아래 `selected_paths`에 명시합니다. 공통 계약, CLI, 루트 훅, 필요한 `scripts` 도구와 `tdd-set` 실행기·정책·템플릿·정식 스킬을 포함합니다. `.agents`의 별칭과 루트 유지보수 스킬, `.codex`, `brain/`, `apps/`, `references/`, 소스 테스트, 계획 문서, 소비 측 설정·lock, Git 메타데이터는 제외합니다.

이 압축 파일을 바로 완성된 종속 모드 설치라고 부르지 않습니다. 기존 doctor·훅에는 아직 소바야 체크아웃과 Git에 대한 가정이 있으므로, 설치·모드 연결 단계에서 분리하고 검증해야 합니다. 여기서 압축 해제 후 실행하는 검사는 이미 구현된 `config check`에 한정됩니다.

반복 생성은 같은 Git·압축 도구 환경에서 확인합니다. 운영체제나 도구 버전이 다른 환경의 바이트 일치, 원격 릴리스 신뢰 확인, 네트워크 차단, 설치 실패 복구·동시 실행·성능·bump는 이 네 항목으로 증명하지 않습니다. 원본의 경로·내용·Unix 권한 비트·심링크 대상과 기존 출력의 대상 폴더 전체를 비교합니다. 수정 시각·소유자·심링크 자체의 권한 보존은 비교 대상이 아닙니다.

## 승인 전 초안 검증과 승인 범위

- 실행용 원본: [`draft-release-tests.sh`](../../brain/plans/04-versioned-modes/draft-release-tests.sh). 승인 후 동일한 바이트를 `tests/test-release.sh`에 옮기고 전체 스위트에 추가했습니다.
- Bash 3.2 문법 검사와 `┎` 설명을 뺀 원문 대조가 통과했습니다.
- 승인 전에는 실제 도구가 없어 `NOT PROBED`였습니다. 이 결과를 RED나 GREEN으로 간주하지 않았습니다.
- 아무 일 없이 성공하는 대조 도구를 넣으면 네 항목 모두 실패하여, 종료 코드 0만으로 통과하지 못함을 확인했습니다.
- 독립 초안 리뷰에서 권한 일부 변경·심링크 대상의 새 파일을 놓치는 문제와 Git 점검 순서 문제를 발견해 수정했습니다. 재검토에서 남은 지적 사항이 없으며, 해당 변조 대조 도구를 모두 거절하는 것도 확인했습니다. 실제 배포 도구의 동작 검증은 아닙니다.

승인 범위는 명령 인수·산출물·메타데이터·파일 범위와 아래 네 테스트 및 공통 준비 코드입니다. [승인 기록](../../brain/plans/04-versioned-modes/release-approval.md)과 [항목별 실제 실패·구현·검증 기록](../../brain/plans/04-versioned-modes/release-validation.md)을 남깁니다. 설치·최초 연결·bump 테스트는 후속 승인 대상입니다.

실행용 초안 SHA-256: `bdc855b56d44cbb1dc60fdc1e256fa647a55dcb560a76906521a27e680473f24`

## 공통 준비와 전체 테스트 코드

아래 설명은 바로 다음 동작을 가리키는 검토용 주석입니다. 기존 주석과 모든 실행 코드는 원문 그대로 보존합니다.

```bash
#!/bin/bash
# DRAFT: release packaging tests require human approval before implementation.
# ┎ 명령 실패·미정의 변수·파이프라인 중간 실패를 테스트 실패로 처리한다.
set -eu
# ┎ 파이프라인의 앞쪽 명령이 실패해도 실패 상태를 유지한다.
set -o pipefail
# ┎ 필요한 도구는 로컬에서 확인하며 자동으로 설치하지 않는다.
for tool in git jq tar gzip shasum; do command -v "$tool" >/dev/null || { printf 'NOT PROBED: missing %s\n' "$tool" >&2; exit 2; }; done
# ┎ 저장소와 배포 도구의 위치를 구한다. 별도 도구를 지정하면 그 도구를 검사한다.
ROOT=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
# ┎ 배포 도구 경로를 지정하지 않았으면 저장소의 기본 배포 스크립트를 검사한다.
PACKAGER=${SOBAYA_PACKAGER:-"$ROOT/scripts/package-release.sh"}
# ┎ 상대 경로는 거절하며, 도구가 없으면 행위 실패 대신 검사 불가로 표시한다.
case "$PACKAGER" in /*) ;; *) printf 'NOT PROBED: absolute SOBAYA_PACKAGER required\n' >&2; exit 2 ;; esac
# ┎ 실행 대상 파일이 없으면 NOT PROBED로 종료한다.
[ -f "$PACKAGER" ] || { printf 'NOT PROBED: package-release.sh is absent\n' >&2; exit 2; }
# ┎ 하위 사례에 같은 도구를 전달하고 사용자 Git 설정의 영향을 차단한다.
export SOBAYA_PACKAGER="$PACKAGER" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
# ┎ 기대와 다르면 해당 사례를 즉시 실패시킨다.
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
# ┎ 지정한 폴더의 경로·내용·Unix 권한 비트·심링크 대상을 기록한다. 수정 시각과 소유자는 비교하지 않는다.
tree_snapshot() {
  # ┎ 폴더 내부의 경로와 정규 파일 내용을 기록한다.
  (cd "$1"; find . -print; find . -type f -exec cksum {} \;
    # ┎ 일부 사용자만의 실행 권한 변경도 잡도록 각 권한 비트를 경로와 함께 따로 기록한다.
    for mask in 4000 2000 1000 400 200 100 040 020 010 004 002 001; do
      # ┎ 심링크 자체의 플랫폼별 권한은 제외하며, 일반 경로의 읽기·쓰기·실행·특수 비트를 기록한다.
      find . ! -type l -perm "-$mask" -print | sed "s|^|mode:$mask |"
    done
    # ┎ 심링크는 따라가지 않고 경로와 연결 대상을 함께 기록한다.
    while IFS= read -r -d '' link; do printf '%s -> %s\n' "$link" "$(readlink "$link")"; done < <(find . -type l -print0)
  # ┎ 같은 상태가 같은 기록이 되도록 정렬해서 지정한 파일에 저장한다.
  ) | LC_ALL=C sort > "$2"
}
# ┎ Git 메타데이터와 승인 상태를 포함한 원본 저장소 전체를 기록한다.
snapshot() {
  # ┎ 공통 폴더 기록 도구를 원본 저장소에 적용한다.
  tree_snapshot "$SOURCE" "$1"
}
# ┎ 기존 출력 경로와, 심링크라면 그 링크가 가리키는 폴더 전체도 기록한다.
output_snapshot() {
  {
    # ┎ 출력 경로 자체의 유형과 권한을 읽는다. 수정 시각은 저장하지 않는다.
    details=$(LC_ALL=C ls -ld "$OUT")
    # ┎ 권한 부분만 기록해 시각·소유자 정보와 구별한다.
    printf 'mode %s\n' "${details%% *}"
    # ┎ 기존 심링크의 연결 대상도 보존되어야 한다.
    if [ -L "$OUT" ]; then printf 'link %s\n' "$(readlink "$OUT")"; fi
    # ┎ 폴더 또는 폴더 심링크는 대상 전체를 기록한다. 기존 일반 파일은 내용을 기록한다.
    if [ -d "$OUT" ]; then
      # ┎ 대상 폴더에 파일이 추가·삭제되거나 내용·권한이 달라지는 경우도 잡는다.
      tree_snapshot "$OUT" "$WORK/output-tree"
      # ┎ 대상 폴더 기록을 출력 경로 기록에 합친다.
      cat "$WORK/output-tree"
    else
      # ┎ 일반 파일은 원래 내용의 체크섬을 기록한다.
      cksum "$OUT"
    fi
  } > "$1"
}
# ┎ 각 항목에 독립된 임시 폴더를 만들고 종료 시 이 폴더만 정리한다.
setup() {
  # ┎ 이번 항목만 사용하는 임시 디렉터리를 만든다.
  WORK=$(mktemp -d "${TMPDIR:-/tmp}/sobaya-package-draft.XXXXXX")
  # ┎ 항목 종료 시 만든 임시 디렉터리를 정리한다.
  trap 'rm -rf "$WORK"' EXIT
}
# ┎ 실제 소바야 코드와 Git 저장소로 배포 원본을 만든다. 개인 데이터 표시는 모두 가짜 내용이다.
fixture() {
  # ┎ 앞선 사례를 지우고 공백·작은따옴표가 들어간 원본 경로를 사용한다.
  rm -rf "$WORK/source's path" "$WORK/release" "$WORK/again" "$WORK/unpacked" "$WORK/consumer" "$WORK/target"
  # ┎ 원본·명령 인수·출력 위치와 시험 출시 버전을 초기화한다.
  SOURCE="$WORK/source's path"; ARG_SOURCE="$SOURCE"; OUT="$WORK/release"; VERSION=1.0.0-rc.1
  # ┎ 원본 파일을 담을 폴더를 만든다.
  mkdir -p "$SOURCE"
  # ┎ 현재 커밋의 파일만 복사하고 별도 Git 저장소로 초기화한다.
  git -C "$ROOT" archive HEAD | tar -xf - -C "$SOURCE"
  # ┎ 복사본에 독립된 Git 메타데이터를 만든다.
  git -C "$SOURCE" init -q
  # ┎ 배포에서 제외할 개인 기록·앱·참조 소스·명세·설정을 만든다.
  mkdir -p "$SOURCE/brain" "$SOURCE/apps/private-app" "$SOURCE/references" "$SOURCE/.source-hooks"
  # ┎ 개인 기억 파일을 흉내 낸 내용을 기록한다.
  printf 'private brain fixture\n' > "$SOURCE/brain/private.md"
  # ┎ 별도 앱의 비공개 파일을 흉내 낸 내용을 기록한다.
  printf 'private app fixture\n' > "$SOURCE/apps/private-app/private.txt"
  # ┎ 참조 저장소의 비공개 파일을 흉내 낸 내용을 기록한다.
  printf 'private reference fixture\n' > "$SOURCE/references/private.txt"
  # ┎ 기존 사람이 작성한 명세를 흉내 낸 파일을 기록한다.
  printf 'human-owned specification\n' > "$SOURCE/spec.md"
  # ┎ 기존 승인 테스트 계획을 흉내 낸 파일을 기록한다.
  printf 'human-approved plan\n' > "$SOURCE/failed-test.md"
  # ┎ 소비 측 설정도 배포에서 제외되는지 검사할 파일을 만든다.
  printf '{}\n' > "$SOURCE/sobaya.json"
  # ┎ 소비 측 lock도 배포에서 제외되는지 검사할 파일을 만든다.
  printf '{}\n' > "$SOURCE/sobaya.lock"
  # ┎ 원본 훅은 실행되면 실패한다. 배포가 원본 개발 작업을 실행하지 않는지도 확인한다.
  printf '#!/bin/sh\nexit 77\n' > "$SOURCE/.source-hooks/pre-commit"
  # ┎ 원본 훅에 실제 실행 권한을 준다.
  chmod 755 "$SOURCE/.source-hooks/pre-commit"
  # ┎ 원본 저장소가 사용하는 훅 경로를 기록한다.
  git -C "$SOURCE" config core.hooksPath .source-hooks
  # ┎ 제외할 데이터도 추적하여 미추적 파일만 제외하는 구현으로 통과하지 못하게 한다.
  git -C "$SOURCE" add -f -A .
  # ┎ 픽스처 준비에만 훅을 비활성화하여 기준 커밋을 만든다.
  git -C "$SOURCE" -c core.hooksPath=/dev/null -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm fixture
  # ┎ 배포에 지정할 40자리 실제 커밋 해시를 읽는다.
  COMMIT=$(git -C "$SOURCE" rev-parse HEAD)
  # ┎ 출시 버전에 해당하는 로컬 경량 태그를 만든다.
  git -C "$SOURCE" tag "v$VERSION" "$COMMIT"
  # ┎ 배포 중 기존 승인·누적 호출 기록이 보존되는지 볼 가짜 상태를 준비한다.
  mkdir -p "$SOURCE/.git/sobaya"
  # ┎ 누적 호출 수가 들어 있는 가짜 승인 상태를 저장한다.
  printf '{"version":1,"calls":7,"active":null}\n' > "$SOURCE/.git/sobaya/state.json"
}
# ┎ 변경한 오류 픽스처를 커밋하고 시험용 태그를 그 커밋에 맞춘다.
retag() {
  # ┎ 오류 사례를 포함한 현재 파일을 Git 인덱스에 반영한다.
  git -C "$SOURCE" add -f -A .
  # ┎ 오류 사례를 실제 커밋으로 만든다.
  git -C "$SOURCE" -c core.hooksPath=/dev/null -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm changed
  # ┎ 변경 후 커밋 해시를 읽는다.
  COMMIT=$(git -C "$SOURCE" rev-parse HEAD)
  # ┎ 시험용 로컬 태그를 변경한 커밋에 맞춘다.
  git -C "$SOURCE" tag -f "v$VERSION" "$COMMIT" >/dev/null
}
# ┎ 배포 대상은 공통 계약·명령·훅·필요한 도구와 정식 런타임 파일이다.
selected_paths() {
  # ┎ 지정 커밋에서 아래에 명시한 배포 대상 경로의 파일 목록을 읽는다.
  git -C "$SOURCE" ls-tree -r --name-only "$COMMIT" -- \
    AGENTS.md bin/sobaya .githooks/pre-commit \
    scripts/brain-index.sh scripts/formatter-listing.awk scripts/index-render.awk \
    scripts/probe.sh scripts/setup.sh scripts/tools-common.sh scripts/workspace-check.sh \
    tdd-set/AGENTS.md tdd-set/README.md tdd-set/spec-template.md \
    tdd-set/failed-test-template.md tdd-set/worker-result.schema.json \
    tdd-set/bin/ tdd-set/lib/ tdd-set/hooks/ tdd-set/policies/ tdd-set/skills/
}
# ┎ 원본 밖에서 실행하고 성공·실패 모두 원본 저장소 보존을 검사한다.
invoke() {
  # ┎ 배포 전 원본 상태를 기록한다.
  snapshot "$WORK/before"
  # ┎ 원본 밖에서 명시한 인수로 도구를 실행하고 종료 상태·stdout·stderr를 각각 받는다.
  if (cd "$WORK"; /bin/bash "$PACKAGER" --source "$ARG_SOURCE" --version "$VERSION" --commit "$COMMIT" --output "$OUT") > "$WORK/stdout" 2> "$WORK/stderr"; then RC=0; else RC=$?; fi
  # ┎ 배포 후 원본 상태를 같은 방식으로 기록한다.
  snapshot "$WORK/after"
  # ┎ 경로·파일 내용·권한·연결 대상 중 하나라도 달라지면 실패시킨다.
  cmp -s "$WORK/before" "$WORK/after" || fail 'packaging changed the source repository'
}
# ┎ 성공 시 압축 파일·메타데이터가 있어야 하고 오류 출력은 없어야 한다.
expect_package() {
  # ┎ 배포 명령을 실행하고 원본 보존을 함께 검사한다.
  invoke
  # ┎ 정상 입력은 종료 코드 0이어야 한다.
  [ "$RC" -eq 0 ] || fail "valid package returned $RC"
  # ┎ 정상 결과에는 stderr 출력이 없어야 한다.
  [ ! -s "$WORK/stderr" ] || fail 'successful package wrote stderr'
  # ┎ 버전을 포함하는 두 산출물의 경로를 정한다.
  ARCHIVE="$OUT/sobaya-$VERSION.tar.gz"; MANIFEST="$OUT/sobaya-$VERSION.json"
  # ┎ 압축 파일과 JSON 메타데이터가 실제로 있어야 한다.
  [ -f "$ARCHIVE" ] && [ -f "$MANIFEST" ] || fail 'release artifacts are missing'
  # ┎ 산출물 두 개 외에 임시 파일이나 숨은 파일을 남기지 않는다.
  count=$(find "$OUT" -mindepth 1 -maxdepth 1 -print | wc -l | tr -d ' ')
  # ┎ 출력 폴더 바로 아래에는 두 산출물만 있어야 한다.
  [ "$count" -eq 2 ] || fail 'unexpected release output'
  # ┎ 완성된 압축 파일의 SHA-256을 독립적으로 계산해 기대 메타데이터를 만든다.
  digest=$(shasum -a 256 "$ARCHIVE"); digest=${digest%% *}
  # ┎ 출시 형식 버전·파일 이름과 정확한 버전·커밋·해시로 기대 JSON을 만든다.
  expected=$(jq -cn --arg version "$VERSION" --arg commit "$COMMIT" --arg sha256 "$digest" '{manifest_version:1,artifact:("sobaya-"+$version+".tar.gz"),runtime:{version:$version,commit:$commit,sha256:$sha256}}')
  # ┎ 메타데이터 파일과 stdout은 각각 정확히 JSON 객체 하나이며 기대값과 같아야 한다.
  for file in "$MANIFEST" "$WORK/stdout"; do
    # ┎ 파일 전체를 읽어 객체 수와 내용이 정확히 맞는지 검사한다.
    jq -e -s --argjson expected "$expected" 'length == 1 and .[0] == $expected' "$file" >/dev/null || fail 'incorrect release manifest or stdout'
  done
}
# ┎ 잘못된 입력은 오류를 진단하고 성공 출력이나 새 출력 폴더를 남기지 않아야 한다.
expect_invalid() {
  # ┎ 오류 입력으로 명령을 실행하고 원본 보존을 함께 검사한다.
  invoke
  # ┎ 입력 오류의 종료 코드는 2여야 한다.
  [ "$RC" -eq 2 ] || fail "invalid package returned $RC instead of 2"
  # ┎ 입력 오류 때 stdout은 비어 있어야 한다.
  [ ! -s "$WORK/stdout" ] || fail 'invalid package wrote stdout'
  # ┎ 진단에 해당 필드나 파일 이름을 포함해야 한다.
  grep -Fq -- "$1" "$WORK/stderr" || fail "diagnostic must identify $1"
  # ┎ 오류가 발생했으면 새 출력 경로나 끊어진 심링크도 생기지 않아야 한다.
  [ ! -e "$OUT" ] && [ ! -L "$OUT" ] || fail 'invalid input published output'
}
# ┎ 첫 항목: 태그로 고정한 파일·권한·해시를 담고 압축을 푼 명령이 실제로 동작해야 한다.
package_pins_runtime_and_manifest() {
  # ┎ 정상 원본 저장소와 시험 태그를 준비한다.
  fixture
  # ┎ 실제 배포 파일과 메타데이터의 성공 조건을 검사한다.
  expect_package
  # ┎ 빠진 파일과 개인 파일 유출을 함께 확인한다.
  selected_paths | sed 's|^|sobaya/|' | LC_ALL=C sort > "$WORK/expected-paths"
  # ┎ 압축 파일에서 디렉터리를 제외한 실제 파일 목록을 읽는다.
  tar -tzf "$ARCHIVE" | sed '/\/$/d' | LC_ALL=C sort > "$WORK/archive-paths"
  # ┎ 압축 안의 파일 목록은 승인할 배포 대상 목록과 같아야 한다.
  cmp -s "$WORK/expected-paths" "$WORK/archive-paths" || fail 'archive does not match runtime file set'
  # ┎ 압축 해제용 임시 폴더를 만든다.
  mkdir -p "$WORK/unpacked"
  # ┎ 실제 산출물을 해당 폴더에 푼다.
  tar -xzf "$ARCHIVE" -C "$WORK/unpacked"
  # ┎ 각 파일의 내용과 실행 권한을 지정 커밋의 실제 파일과 비교한다.
  while IFS= read -r path; do
    # ┎ 압축을 푼 파일의 경로를 구한다.
    file="$WORK/unpacked/sobaya/$path"
    # ┎ 압축을 푼 파일은 심링크가 아닌 정규 파일이어야 한다.
    [ -f "$file" ] && [ ! -L "$file" ] || fail "not a regular runtime file: $path"
    # ┎ 지정한 Git 커밋의 원본 파일 바이트를 읽는다.
    git -C "$SOURCE" show "$COMMIT:$path" > "$WORK/blob"
    # ┎ 압축 파일의 내용이 커밋 원본에서 변형되지 않았는지 비교한다.
    cmp -s "$WORK/blob" "$file" || fail "wrong committed content: $path"
    # ┎ 해당 파일의 Git 실행 권한 정보를 읽는다.
    mode=$(git -C "$SOURCE" ls-tree "$COMMIT" -- "$path" | awk '{print $1}')
    # ┎ 실행 파일은 실행 가능해야 하고 일반 파일은 새 실행 권한을 얻지 않아야 한다.
    case "$mode" in 100755) [ -x "$file" ] || fail "executable bit lost: $path" ;; 100644) [ ! -x "$file" ] || fail "unexpected executable: $path" ;; *) fail "unsupported source mode: $path" ;; esac
  done < <(selected_paths)
  # ┎ 실제 산출물의 버전·커밋·해시로 별도 소비 프로젝트 설정을 만든다.
  mkdir "$WORK/consumer"
  # ┎ 같은 출시 버전을 고정한 종속 모드 설정을 만든다.
  jq -n --arg version "$VERSION" '{config_version:1,mode:"dependency",runtime:{version:$version}}' > "$WORK/consumer/sobaya.json"
  # ┎ 배포 결과의 실제 커밋·해시를 사용하는 소비 측 lock을 만든다.
  jq '{lock_version:1,runtime:.runtime}' "$MANIFEST" > "$WORK/consumer/sobaya.lock"
  # ┎ Git 메타데이터 없는 압축 해제본으로 기존 설정 검사 기능을 실행한다. 전체 TDD 설치 검증은 아니다.
  [ ! -e "$WORK/unpacked/sobaya/.git" ] || fail 'Git metadata leaked'
  # ┎ 압축을 푼 CLI로 소비 측 설정을 검사하고 출력과 오류를 나눠 받는다.
  (cd "$WORK"; "$WORK/unpacked/sobaya/bin/sobaya" config check --root "$WORK/consumer") > "$WORK/check-out" 2> "$WORK/check-err"
  # ┎ 정상 설정 검사에서 오류 출력이 나오면 실패시킨다.
  [ ! -s "$WORK/check-err" ] || fail 'unpacked config check wrote stderr'
  # ┎ 소비 측 설정 검사에서 반환해야 할 JSON을 만든다.
  expected=$(jq '{config_version:1,mode:"dependency",runtime:.runtime}' "$MANIFEST")
  # ┎ 실행 결과가 기대한 설정 JSON 객체 하나인지 확인한다.
  jq -e -s --argjson expected "$expected" 'length == 1 and .[0] == $expected' "$WORK/check-out" >/dev/null || fail 'unpacked config check failed'
}
# ┎ 두 번째 항목: 같은 도구에서 같은 커밋은 같은 바이트를 만들며 작업 중인 내용과 무관해야 한다.
package_is_repeatable_from_pinned_commit() {
  # ┎ 반복 생성 검사용 정상 원본을 준비한다.
  fixture
  # ┎ 첫 번째 배포가 성공하고 메타데이터가 올바른지 검사한다.
  expect_package
  # ┎ 첫 번째 출력 폴더를 비교 기준으로 보관한다.
  first="$OUT"
  # ┎ 실행 파일의 미커밋 변경과 미추적 개인 파일을 일부러 넣는다.
  printf 'dirty working file\n' > "$SOURCE/bin/sobaya"
  # ┎ Git에 추가하지 않은 개인 파일을 만든다.
  printf 'untracked private fixture\n' > "$SOURCE/private-untracked.txt"
  # ┎ 두 번째 결과를 별도의 새 디렉터리에 만든다.
  OUT="$WORK/again"
  # ┎ 미커밋 변경이 있어도 고정한 커밋의 배포가 성공해야 한다.
  expect_package
  # ┎ 두 압축 파일은 바이트까지 같아야 한다.
  cmp -s "$first/sobaya-$VERSION.tar.gz" "$ARCHIVE" || fail 'archive changed for the same commit'
  # ┎ 두 JSON 메타데이터도 바이트까지 같아야 한다.
  cmp -s "$first/sobaya-$VERSION.json" "$MANIFEST" || fail 'manifest changed for the same commit'
  # ┎ 주석형 태그도 태그 객체가 아닌 같은 커밋으로 해석해야 한다.
  git -C "$SOURCE" tag -d "v$VERSION" >/dev/null
  # ┎ 같은 커밋을 가리키는 로컬 주석형 태그를 만든다.
  git -C "$SOURCE" -c user.name=Fixture -c user.email=fixture@example.invalid tag -a "v$VERSION" -m release "$COMMIT"
  # ┎ 시험용 두 번째 출력만 정리해 새 출력 경로로 되돌린다.
  rm -rf "$OUT"
  # ┎ 주석형 태그를 사용한 배포도 성공해야 한다.
  expect_package
  # ┎ 태그 종류가 바뀌어도 같은 커밋의 압축 파일은 같아야 한다.
  cmp -s "$first/sobaya-$VERSION.tar.gz" "$ARCHIVE" || fail 'annotated tag changed pinned archive'
  # ┎ 내보내기 속성이 소스 파일을 생략하거나 내용을 치환해도 원래 코드 그대로 배포해야 한다.
  fixture
  # ┎ 실행 파일 생략과 문자열 치환을 유도하는 Git 속성을 원본 커밋에 넣는다.
  printf 'bin/sobaya export-ignore\nAGENTS.md export-subst\n' > "$SOURCE/.gitattributes"
  # ┎ Git 내보내기가 치환할 수 있는 문자열을 실제 파일 내용으로 기록한다.
  printf '\n$Format:%%H$\n' >> "$SOURCE/AGENTS.md"
  # ┎ 속성과 내용 변경을 커밋하고 버전 태그를 맞춘다.
  retag
  # ┎ 속성과 무관하게 정확한 커밋 파일로 배포해야 한다.
  expect_package
  # ┎ 생략 대상 실행 파일과 치환 대상 계약 문서 모두 커밋 원문과 같아야 한다.
  for path in bin/sobaya AGENTS.md; do
    # ┎ 실제 압축 파일에서 해당 파일의 바이트를 읽는다.
    tar -xOzf "$ARCHIVE" "sobaya/$path" > "$WORK/archived-blob"
    # ┎ Git 객체에서 원본 바이트를 읽는다.
    git -C "$SOURCE" show "$COMMIT:$path" > "$WORK/source-blob"
    # ┎ 내보내기 속성으로 생략·치환된 배포 파일을 거절한다.
    cmp -s "$WORK/source-blob" "$WORK/archived-blob" || fail 'export attributes changed runtime bytes'
  done
}
# ┎ 세 번째 항목: 별칭·축약 커밋·태그 불일치·불완전한 파일을 출시로 포장하지 않는다.
package_rejects_invalid_identity_and_payload() {
  # ┎ 오류 입력 검사에 사용할 정상 원본을 먼저 준비한다.
  fixture
  # ┎ 정확한 출시 버전만 받으며 버전을 경로나 옵션으로 해석하지 않는다.
  for VERSION in latest main '^1.0.0' v1.0.0 01.0.0 '../escape' ''; do expect_invalid version; done
  # ┎ 버전을 정상값으로 되돌린다.
  VERSION=1.0.0-rc.1
  # ┎ 정상 커밋 해시를 따로 보관한다.
  pinned=$COMMIT
  # ┎ HEAD·브랜치·축약 해시·존재하지 않는 전체 해시는 거절해야 한다.
  for COMMIT in HEAD main "${pinned:0:7}" 0000000000000000000000000000000000000000; do expect_invalid commit; done
  # ┎ 커밋 인수를 정상값으로 되돌린다.
  COMMIT=$pinned
  # ┎ 존재하지 않는 원본과 저장소 하위 경로는 거절한다.
  for ARG_SOURCE in "$WORK/absent" "$SOURCE/tdd-set"; do expect_invalid source; done
  # ┎ 원본 인수를 정상 저장소 루트로 되돌린다.
  ARG_SOURCE=$SOURCE
  # ┎ 버전에 해당하는 로컬 태그가 없거나 지정 커밋과 다르면 거절한다.
  git -C "$SOURCE" tag -d "v$VERSION" >/dev/null
  # ┎ 출시 태그가 없음을 진단하고 출력하지 않아야 한다.
  expect_invalid tag
  # ┎ 정상 태그를 다시 만든다.
  git -C "$SOURCE" tag "v$VERSION" "$COMMIT"
  # ┎ 태그는 그대로 두고 다른 실제 커밋을 만든다.
  git -C "$SOURCE" -c core.hooksPath=/dev/null -c user.name=Fixture -c user.email=fixture@example.invalid commit --allow-empty -qm next
  # ┎ 태그와 다른 새 커밋을 배포 인수로 선택한다.
  COMMIT=$(git -C "$SOURCE" rev-parse HEAD)
  # ┎ 버전 태그와 인수 커밋의 불일치를 진단해야 한다.
  expect_invalid tag
  # ┎ 필수 실행 파일의 누락과 심링크를 거절한다. 심링크 대상은 배포하지 않는다.
  for shape in missing symlink; do
    # ┎ 파일 유형 사례마다 독립된 정상 원본으로 시작한다.
    fixture
    # ┎ 필수 실행 파일을 원본에서 제거한다.
    rm "$SOURCE/bin/sobaya"
    # ┎ 심링크 사례는 외부 파일을 가리키는 링크로 대체한다.
    if [ "$shape" = symlink ]; then
      # ┎ 실제 시스템 파일 대신 배포 대상이 아닌 가짜 외부 파일을 만든다.
      printf 'outside fixture\n' > "$WORK/outside-file"
      # ┎ 선택된 실행 파일을 이 외부 파일의 심링크로 바꾼다.
      ln -s "$WORK/outside-file" "$SOURCE/bin/sobaya"
    fi
    # ┎ 파일 상태를 커밋하고 태그를 맞춰 태그 불일치와 구별한다.
    retag
    # ┎ 필수 실행 파일의 오류를 진단해야 한다.
    expect_invalid bin/sobaya
  done
  # ┎ 선택 경로의 Git 서브모듈을 조용히 제외하고 완성된 묶음처럼 보고하지 않는다.
  fixture
  # ┎ 배포 대상 하위에 Git 서브모듈 항목을 인덱스로 넣는다.
  git -C "$SOURCE" update-index --add --cacheinfo "160000,$COMMIT,tdd-set/lib/foreign"
  # ┎ 서브모듈 항목이 있는 원본 커밋을 만든다.
  git -C "$SOURCE" -c core.hooksPath=/dev/null -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm gitlink
  # ┎ 새 커밋 해시를 읽는다.
  COMMIT=$(git -C "$SOURCE" rev-parse HEAD)
  # ┎ 시험 태그를 새 커밋에 맞춘다.
  git -C "$SOURCE" tag -f "v$VERSION" "$COMMIT" >/dev/null
  # ┎ 포함할 수 없는 서브모듈 경로를 진단해야 한다.
  expect_invalid tdd-set/lib/foreign
}
# ┎ 네 번째 항목: 기존 출력 경로·연결 대상·원본 저장소를 보존한다.
package_preserves_existing_output_and_source() {
  # ┎ 기존 경로는 빈 폴더라도 덮어쓰지 않으며 파일·심링크도 같은 기준으로 거절한다.
  for shape in empty directory file symlink; do
    # ┎ 기존 출력 경로 사례마다 원본과 출력 위치를 초기화한다.
    fixture
    # ┎ 기존 출력 경로의 유형별로 픽스처를 만든다.
    case "$shape" in
      # ┎ 이미 존재하는 빈 디렉터리를 만든다.
      empty) mkdir "$OUT" ;;
      # ┎ 이미 존재하며 보존할 파일이 들어 있는 디렉터리를 만든다.
      directory) mkdir "$OUT"; printf 'keep\n' > "$OUT/keep" ;;
      # ┎ 출력 경로를 기존 일반 파일로 만든다.
      file) printf 'keep\n' > "$OUT" ;;
      # ┎ 별도 폴더와 내용을 가리키는 기존 심링크를 만든다.
      symlink) mkdir "$WORK/target"; printf 'keep\n' > "$WORK/target/keep"; ln -s "$WORK/target" "$OUT" ;;
    esac
    # ┎ 실행 전후 기존 출력과 심링크 대상의 내용·유형을 비교한다.
    output_snapshot "$WORK/output-before"
    # ┎ 같은 경로로 배포를 시도한다.
    invoke
    # ┎ 기존 출력 경로는 오류로 거절하고 stdout을 비워야 한다.
    [ "$RC" -eq 2 ] && [ ! -s "$WORK/stdout" ] || fail 'existing output was accepted'
    # ┎ 출력 경로 문제임을 진단해야 한다.
    grep -Fq output "$WORK/stderr" || fail 'missing output diagnostic'
    # ┎ 실행 후 같은 출력 경로와 연결 대상 정보를 기록한다.
    output_snapshot "$WORK/output-after"
    # ┎ 기존 내용·유형·연결 대상 정보가 달라지면 실패시킨다.
    cmp -s "$WORK/output-before" "$WORK/output-after" || fail 'existing output changed'
  done
  # ┎ 원본 저장소 안에 출력물을 만들어 원본을 바꾸는 경우도 거절한다.
  fixture
  # ┎ 출력 위치를 원본 저장소 내부의 새 경로로 바꾼다.
  OUT="$SOURCE/release"
  # ┎ 원본을 바꾸는 출력 위치를 거절해야 한다.
  expect_invalid output
}
# ┎ 한 항목을 하위 프로세스로 실행해 set -e가 실패를 확실히 중단하게 한다.
if [ "${1:-}" = __case ]; then
  # ┎ 이 하위 프로세스의 독립 임시 폴더를 준비한다.
  setup
  # ┎ 지정한 테스트 함수 하나만 실행한다.
  "$2"
  # ┎ 항목이 끝나면 정리 절차를 실행하며 종료한다.
  exit
fi
# ┎ 네 항목의 실제 결과를 집계한다. 어느 하나라도 실패하면 전체 종료 상태도 실패다.
failures=0
# ┎ 네 항목을 정해진 순서대로 검사한다.
for name in package_pins_runtime_and_manifest package_is_repeatable_from_pinned_commit package_rejects_invalid_identity_and_payload package_preserves_existing_output_and_source; do
  # ┎ 별도 Bash 프로세스로 해당 항목을 실행한다.
  if /bin/bash "$0" __case "$name"; then
    # ┎ 해당 항목이 모두 끝났을 때만 PASS로 표시한다.
    printf 'PASS: %s\n' "$name"
  else
    # ┎ 실패한 항목을 표시한다.
    printf 'FAIL: %s\n' "$name"
    # ┎ 실패 횟수를 하나 늘린다.
    failures=$((failures + 1))
  fi
done
# ┎ 실패 항목이 하나라도 있으면 전체 실행을 실패로 반환한다.
[ "$failures" -eq 0 ]
```
