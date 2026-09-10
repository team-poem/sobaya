# Validate a unified diff: insert imports before functions or append new tests.
/^@@ / {
 split($2,a,",");pos=a[1];sub(/^-/,"",pos);in_hunk=1;next
}
!in_hunk {next}
/^-/{bad=1;next}
/^\+/ {
 line=substr($0,2)
 if(pos==total)next
 if(pos>firstfunc){bad=1;next}
 if(line !~ /^[[:space:]]*(import[[:space:]]+(\(|([A-Za-z_][A-Za-z0-9_]*[[:space:]]+)?"[^"\n]+")|([A-Za-z_][A-Za-z0-9_]*[[:space:]]+)?"[^"\n]+"|\))?[[:space:]]*$/)bad=1
}
END{exit bad}
