# Input: sorted vault-relative paths, one per line.
/\.md$/ && $0 != "index.md" && $0 !~ "^(archive/)?plans/[^/]+/" {
  name=$0; sub(/\.md$/, "", name); group=8
  if (name == "vision") group=1
  else if (name == "principles" || name ~ /^principles\//) group=2
  else if (name == "apps") group=3
  else if (name ~ /^codebase\//) group=4
  else if (name == "todos") group=5
  else if (name == "plans/index") group=6
  else if (name ~ /^archive\//) group=7
  rows[group]=rows[group] "- [[" name "]]\n"
}
END {
  title[1]="Vision"; title[2]="Principles"; title[3]="Apps"; title[4]="Codebase"
  title[5]="Backlog"; title[6]="Plans"; title[7]="Archive"; title[8]="Other"
  printf "# Brain\n"
  for (i=1; i<=8; i++) if (rows[i] != "") printf "\n## %s\n%s", title[i], rows[i]
}
