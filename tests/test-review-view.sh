#!/bin/bash
# Root-maintenance checks for review rendering; never approve an app or run its code.
set -eu
set -o pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd -P)
tool=$ROOT/tdd-set/bin/review-view.sh
[ -f "$tool" ] || { echo 'NOT PROBED: review-view.sh is absent' >&2; exit 2; }
tmp=$(mktemp -d "${TMPDIR:-/tmp}/sobaya review ' XXXX")
trap 'rm -rf "$tmp"' EXIT
source_file=$tmp/source.sh
notes=$tmp/notes.json
cat > "$source_file" <<'SOURCE'
# Original comment and literal Markdown remain code.
value=7

check_value() {
  printf '%s\n' '```'
  [ "$value" -eq 7 ]
}
SOURCE
digest=$(shasum -a 256 "$source_file"); digest=${digest%% *}
jq -n --arg hash "$digest" '{review_version:1,source_sha256:$hash,
  target:"suite.sh",entry:"check_value",language:"bash",regions:[
    {start:1,end:3,what:"초기값을 준비한다.",why:"보존 비교에 비어 있지 않은 값이 필요하다.",basis:"7은 구분용 임의값이다.",relates_to:"아래 함수가 사용할 입력이며 자체 단언은 없다."},
    {start:4,end:7,what:"출력 후 값이 7인지 확인하는 함수를 정의한다.",why:"실행 시 변경된 값을 검출한다.",basis:"기대값 7은 준비값과 같은 값이다.",relates_to:"이 파일만으로 함수가 호출되거나 테스트로 등록되지는 않는다."}
  ]}' > "$notes"
pass=0
good() { pass=$((pass+1)); printf 'ok %d - %s\n' "$pass" "$1"; }
reject() {
  local label=$1 input=$2 mapping=$3
  rm -f "$tmp/rejected.md"
  if /bin/bash "$tool" "$input" "$mapping" "$tmp/rejected.md" > "$tmp/result" 2> "$tmp/error"; then
    echo "FAIL: accepted $label" >&2; exit 1
  fi
  [ ! -e "$tmp/rejected.md" ] && [ -s "$tmp/error" ] || { echo "FAIL: partial output or missing diagnosis: $label" >&2; exit 1; }
  good "$label"
}
extract() {
  # Read the sole complete code fence, using its actual delimiter (source contains ```).
  awk '
    !inside && /^```/ {fence=$0; sub(/[^`].*$/, "", fence); inside=1; next}
    inside && $0==fence {exit}
    inside {print}
  ' "$1" > "$tmp/extracted"
  bytes=$(wc -c < "$source_file" | tr -d ' ')
  dd if="$tmp/extracted" of="$tmp/recovered" bs=1 count="$bytes" 2>/dev/null
  cmp "$source_file" "$tmp/recovered"
}
cp "$source_file" "$tmp/source.before"; cp "$notes" "$tmp/notes.before"
/bin/bash "$tool" "$source_file" "$notes" "$tmp/review.md" > "$tmp/result"
jq -e '.review_only==true and .lines==7 and .regions==2' "$tmp/result" >/dev/null
extract "$tmp/review.md"
cmp "$source_file" "$tmp/source.before"; cmp "$notes" "$tmp/notes.before"
good 'complete source remains contiguous and byte recoverable; inputs unchanged'
grep -Fq '┎ L1–L3' "$tmp/review.md" && grep -Fq '┎ L4–L7' "$tmp/review.md"
grep -Fq '7은 구분용 임의값이다.' "$tmp/review.md"
good 'range-specific rationale and arbitrary-value basis appear outside code'

for variant in gap overlap reorder tail beyond fractional missing blank duplicate stale newline control language language-lf type; do
  case "$variant" in
    gap) filter='.regions[1].start=5' ;;
    overlap) filter='.regions[1].start=3' ;;
    reorder) filter='.regions |= reverse' ;;
    tail) filter='.regions[1].end=6' ;;
    beyond) filter='.regions[1].end=8' ;;
    fractional) filter='.regions[0].end=2.5' ;;
    missing) filter='del(.regions[0].why)' ;;
    blank) filter='.regions[0].basis="  "' ;;
    duplicate) filter='.regions += [.regions[1]]' ;;
    stale) filter='.source_sha256=("0" * 64)' ;;
    newline) filter='.regions[0].why="first\nsecond"' ;;
    control) filter='.entry="hidden\u0085line"' ;;
    language) filter='.language="bash`"' ;;
    language-lf) filter='.language="bash\n"' ;;
    type) filter='.regions={start:1,end:7}' ;;
  esac
  jq "$filter" "$notes" > "$tmp/bad.json"
  reject "$variant mapping refused" "$source_file" "$tmp/bad.json"
done
cat "$notes" "$notes" > "$tmp/bad.json"
reject 'multiple JSON documents refused' "$source_file" "$tmp/bad.json"
printf '{' > "$tmp/bad.json"
reject 'malformed JSON refused' "$source_file" "$tmp/bad.json"
cat "$notes" > "$tmp/bad.json"; printf '\000' >> "$tmp/bad.json"
reject 'raw NUL in notes refused before JSON parsing' "$source_file" "$tmp/bad.json"
printf '\000' >> "$source_file"
reject 'binary source refused' "$source_file" "$notes"
cp "$tmp/source.before" "$source_file"

: > "$tmp/empty"
reject 'empty source refused' "$tmp/empty" "$notes"
printf '\377' > "$tmp/non-utf8"
reject 'invalid UTF-8 source refused' "$tmp/non-utf8" "$notes"
for content in 'one\rtwo\rthree\r' 'one\r\ntwo\rthree\nfour'; do
  printf '%b' "$content" > "$tmp/bare-cr"
  hash=$(shasum -a 256 "$tmp/bare-cr"); hash=${hash%% *}
  count=$(awk 'END {print NR}' "$tmp/bare-cr")
  jq --arg hash "$hash" --argjson count "$count" '.source_sha256=$hash | .regions=[.regions[0] | .start=1 | .end=$count]' "$notes" > "$tmp/bare-cr.json"
  reject 'bare CR source cannot misalign displayed ranges' "$tmp/bare-cr" "$tmp/bare-cr.json"
done
jq '.regions[0].why=("긴 한국어 설계 이유를 원본 밖에서 설명한다. " * 300)' "$notes" > "$tmp/long-notes.json"
/bin/bash "$tool" "$source_file" "$tmp/long-notes.json" "$tmp/long.md" >/dev/null
grep -Fq '긴 한국어 설계 이유를 원본 밖에서 설명한다.' "$tmp/long.md"
good 'long Korean rationale validates and renders'
printf 'touch "%s"\n' "$tmp/source-executed" > "$tmp/executable-source"
hash=$(shasum -a 256 "$tmp/executable-source"); hash=${hash%% *}
jq --arg hash "$hash" '.source_sha256=$hash | .regions=[.regions[0] | .start=1 | .end=1]' "$notes" > "$tmp/executable-notes"
/bin/bash "$tool" "$tmp/executable-source" "$tmp/executable-notes" "$tmp/unexecuted.md" >/dev/null
[ ! -e "$tmp/source-executed" ]
good 'rendering never executes the supplied source'

for ending in crlf no-final-lf; do
  case "$ending" in
    crlf) awk '{printf "%s\r\n", $0}' "$tmp/source.before" > "$source_file" ;;
    no-final-lf) bytes=$(wc -c < "$tmp/source.before"); dd if="$tmp/source.before" of="$source_file" bs=1 count=$((bytes-1)) 2>/dev/null ;;
  esac
  hash=$(shasum -a 256 "$source_file"); hash=${hash%% *}
  jq --arg hash "$hash" '.source_sha256=$hash' "$notes" > "$tmp/ending.json"
  /bin/bash "$tool" "$source_file" "$tmp/ending.json" "$tmp/$ending.md" >/dev/null
  extract "$tmp/$ending.md"
  good "$ending code bytes recover without rewriting the input"
done
cp "$tmp/source.before" "$source_file"
if /bin/bash "$tool" "$source_file" "$notes" "$source_file" > "$tmp/result" 2> "$tmp/error"; then exit 1; fi
cmp "$source_file" "$tmp/source.before"
good 'existing output/input cannot be overwritten'
ln -s "$tmp/not-created" "$tmp/link.md"
if /bin/bash "$tool" "$source_file" "$notes" "$tmp/link.md" > "$tmp/result" 2> "$tmp/error"; then exit 1; fi
[ -L "$tmp/link.md" ] && [ ! -e "$tmp/not-created" ]
good 'dangling output symlink cannot redirect writes'

# Competing publication after validation must never overwrite or follow a path.
mkdir "$tmp/bin"
export REVIEW_REAL_CMP
REVIEW_REAL_CMP=$(command -v cmp)
export REVIEW_RACE_NOTES="$notes" REVIEW_RACE_OUTPUT="$tmp/raced.md"
cat > "$tmp/bin/cmp" <<'RACE'
#!/bin/bash
if [ "$#" -ge 2 ] && [ "$2" = "$REVIEW_RACE_NOTES" ]; then
  case "$REVIEW_RACE_KIND" in
    symlink) ln -s /dev/null "$REVIEW_RACE_OUTPUT" ;;
    directory) mkdir "$REVIEW_RACE_OUTPUT" ;;
    file) printf 'competing file\n' > "$REVIEW_RACE_OUTPUT" ;;
  esac
fi
exec "$REVIEW_REAL_CMP" "$@"
RACE
chmod +x "$tmp/bin/cmp"
for kind in symlink directory file; do
  if PATH="$tmp/bin:$PATH" REVIEW_RACE_KIND=$kind /bin/bash "$tool" "$source_file" "$notes" "$tmp/raced.md" > "$tmp/result" 2> "$tmp/error"; then
    echo "FAIL: accepted raced $kind" >&2; exit 1
  fi
  [ ! -s "$tmp/result" ] && [ -s "$tmp/error" ]
  case "$kind" in
    symlink) [ -L "$tmp/raced.md" ] && [ "$(readlink "$tmp/raced.md")" = /dev/null ]; rm "$tmp/raced.md" ;;
    directory) rmdir "$tmp/raced.md" ;; # Must remain empty.
    file) [ "$(cat "$tmp/raced.md")" = 'competing file' ]; rm "$tmp/raced.md" ;;
  esac
  good "raced $kind preserved without successful receipt"
done
printf 'PASS: %d review-view checks\n' "$pass"
