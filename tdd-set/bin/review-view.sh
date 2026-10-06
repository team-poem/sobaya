#!/bin/bash
# Render a human-only review without executing or rewriting its source.
set -eu
set -o pipefail
export LC_ALL=C

fail() { printf 'review-view: %s\n' "$*" >&2; exit 2; }
[ "$#" -eq 3 ] || fail 'usage: review-view.sh SOURCE NOTES_JSON NEW_OUTPUT.md'
source_file=$1
notes_file=$2
output=$3
case "$source_file" in /*) ;; *) source_file=$PWD/$source_file ;; esac
case "$notes_file" in /*) ;; *) notes_file=$PWD/$notes_file ;; esac
case "$output" in /*) ;; *) output=$PWD/$output ;; esac
[ -f "$source_file" ] && [ -r "$source_file" ] || fail 'source must be a readable regular file'
[ -f "$notes_file" ] && [ -r "$notes_file" ] || fail 'notes must be a readable regular file'
[ ! -e "$output" ] && [ ! -L "$output" ] || fail 'output already exists; choose a new path'
for command in jq awk cat cmp tr wc tail od iconv mktemp link; do
  command -v "$command" >/dev/null 2>&1 || fail "missing command: $command"
done
if command -v shasum >/dev/null 2>&1; then
  hash_file() { shasum -a 256 < "$1" | awk '{print $1}'; }
elif command -v sha256sum >/dev/null 2>&1; then
  hash_file() { sha256sum < "$1" | awk '{print $1}'; }
else
  fail 'shasum or sha256sum is required'
fi

tmp=$(mktemp -d "${TMPDIR:-/tmp}/sobaya-review.XXXXXX")
stage=
trap 'rm -rf "$tmp"; [ -z "$stage" ] || rm -f "$stage"' EXIT
cat < "$source_file" > "$tmp/source"
cat < "$notes_file" > "$tmp/notes"
[ -s "$tmp/source" ] || fail 'source is empty'
tr -d '\000' < "$tmp/source" > "$tmp/text"
cmp -s "$tmp/source" "$tmp/text" || fail 'source contains NUL bytes'
tr -d '\000' < "$tmp/notes" > "$tmp/text"
cmp -s "$tmp/notes" "$tmp/text" || fail 'notes contain NUL bytes'
# macOS iconv can fail on long UTF-8 input when its output is /dev/null.
iconv -f UTF-8 -t UTF-8 < "$tmp/source" > "$tmp/utf8-source" || fail 'source must be UTF-8 text'
iconv -f UTF-8 -t UTF-8 < "$tmp/notes" > "$tmp/utf8-notes" || fail 'notes must be UTF-8 JSON'
digest=$(hash_file "$tmp/source")
lines=$(awk 'END {print NR}' "$tmp/source")
bytes=$(wc -c < "$tmp/source" | tr -d '[:space:]')
last_byte=$(tail -c 1 "$tmp/source" | od -An -tu1 | tr -d '[:space:]')
# Markdown treats a bare CR as a new line too; do not accept an ambiguous map.
awk '{sub(/\r$/, ""); if (index($0, "\r")) exit 1}' "$tmp/source" &&
  [ "$last_byte" != 13 ] || fail 'source must use LF or CRLF; bare CR is unsupported'
final_lf=false
[ "$last_byte" != 10 ] || final_lf=true

# Slurp first: jq otherwise accepts multiple independent JSON documents.
jq -es --arg hash "$digest" --argjson lines "$lines" '
  def text: type == "string" and test("\\S") and (test("[\u0000-\u001f\u007f-\u009f\u2028\u2029]") | not);
  def integer: type == "number" and . == floor;
  length == 1 and (.[0] |
    type == "object" and
    .review_version == 1 and .source_sha256 == $hash and
    (.target | text) and (.entry | text) and
    (.language | text and test("^[A-Za-z0-9_+-]+$")) and
    (.regions | type == "array" and length > 0) and
    all(.regions[];
      type == "object" and
      (.start | integer) and (.end | integer) and
      .start >= 1 and .end >= .start and .end <= $lines and
      (.what | text) and (.why | text) and (.basis | text) and (.relates_to | text)) and
    (reduce .regions[] as $r ({next:1,ok:true};
      {next:($r.end + 1),ok:(.ok and $r.start == .next)}) |
      .ok and .next == ($lines + 1)))
' "$tmp/notes" >/dev/null || fail 'invalid notes: require one object, matching source hash, four nonblank fields, and an ordered full-line partition'

regions=$(jq '.regions | length' "$tmp/notes")
# A longer fence also protects embedded Markdown in test data or heredocs.
fence=$(awk '
  BEGIN {longest=2}
  {rest=$0; while (match(rest, /`+/)) {
    if (RLENGTH > longest) longest=RLENGTH
    rest=substr(rest, RSTART+RLENGTH)
  }}
  END {for (i=0; i<=longest; i++) printf "`"}
' "$tmp/source")
language=$(jq -r '.language' "$tmp/notes")
cat > "$tmp/escape.jq" <<'JQ'
def md: @html | gsub("\\\\"; "&#92;") | gsub("`"; "&#96;") |
  gsub("\\*"; "&#42;") | gsub("_"; "&#95;") |
  gsub("\\["; "&#91;") | gsub("\\]"; "&#93;");
JQ
{
  printf '# 테스트 검토용 보기\n\n'
  jq -r -f <(cat "$tmp/escape.jq"; printf '%s\n' '"대상: \(.target | md) · 항목: \(.entry | md)"') "$tmp/notes"
  # Markdown backticks are literal presentation.
  # shellcheck disable=SC2016
  printf '\n원본 SHA-256: `%s`  \n' "$digest"
  printf '원본: %s bytes · %s lines · final LF: %s\n\n' "$bytes" "$lines" "$final_lf"
  printf '아래 코드 블록은 원본 전체이며, 설명은 실행 파일에 포함되지 않습니다.\n\n'
  if [ "$final_lf" = false ]; then
    printf '원본에는 마지막 LF가 없습니다. 닫는 코드 펜스 앞 LF 하나는 표시용 구분자이며 원본 바이트에 포함되지 않습니다.\n\n'
  fi
  printf '%s%s\n' "$fence" "$language"
  cat "$tmp/source"
  [ "$final_lf" = true ] || printf '\n'
  printf '%s\n\n' "$fence"
  jq -r -f <(cat "$tmp/escape.jq"; cat <<'JQ'
.regions[] |
  "┎ L\(.start)–L\(.end)\n\n- **동작:** \(.what | md)\n- **이유:** \(.why | md)\n- **근거·가정:** \(.basis | md)\n- **검증과의 관계:** \(.relates_to | md)\n"
JQ
  ) "$tmp/notes"
  printf '\n구간·해시 검사는 설명의 정확성, 요구사항 충족, 검토 목록에서 빠진 파일을 증명하지 않습니다. 이 보기는 승인이나 테스트 실행 결과가 아닙니다.\n'
} > "$tmp/rendered.md"

# Stage on the destination filesystem. POSIX link (not ln) atomically refuses
# every existing final path, including raced directories and device symlinks.
stage=$(mktemp "${output%/*}/.sobaya-review.XXXXXX") || fail 'cannot stage output in its parent directory'
cat "$tmp/rendered.md" > "$stage"
cmp -s "$source_file" "$tmp/source" || fail 'source changed during rendering; regenerate notes'
cmp -s "$notes_file" "$tmp/notes" || fail 'notes changed during rendering; retry'
link "$stage" "$output" || fail 'cannot create new output'
jq -n --arg output "$output" --arg hash "$digest" --argjson lines "$lines" \
  --argjson bytes "$bytes" --argjson regions "$regions" --argjson final_lf "$final_lf" \
  '{review_only:true,output:$output,source_sha256:$hash,bytes:$bytes,lines:$lines,regions:$regions,final_lf:$final_lf}'
