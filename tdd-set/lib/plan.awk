# Parse mutable behavioral scenarios and an optional next executable test.
function q(s,    i,c,r) { r="\""; for(i=1;i<=length(s);i++){c=substr(s,i,1);if(c=="\\")r=r"\\\\";else if(c=="\"")r=r"\\\"";else if(c=="\t")r=r"\\t";else if(c=="\r")r=r"\\r";else if(c=="\n")r=r"\\n";else r=r c}return r"\"" }
function bad(s){print s > "/dev/stderr";failed=1;exit 1}
function emit(    target,n,a,j){
 if(block!="" && (lang !~ /^(go|js|javascript|ts|typescript|jsx|tsx)$/ || block !~ /[^[:space:]]/ || block ~ /(^|\n)[[:space:]]*\.\.\.[[:space:]]*(\n|$)/))bad("missing, unsupported, or placeholder code: "name)
 target=""; n=split(header,a,"\n");for(j=1;j<=n;j++)if(a[j] ~ /^\/\/ file:[[:space:]]*/){target=a[j];sub(/^\/\/ file:[[:space:]]*/,"",target);sub(/[[:space:]]*$/,"",target)}
 if(target ~ /^\// || target ~ /(^|\/)\.\.(\/|$)/ || target ~ /\\/ || target ~ /[[:space:]]/)bad("test target must stay inside app: "target)
 if(block!="" && lang!="go" && target=="")bad("Node plan section needs a // file: header: "name)
 print "{\"name\":"q(name)",\"description\":"q(description)",\"checked\":"checked",\"code\":"q(block)",\"header\":"q(header)",\"heading\":"q(heading)",\"language\":"q(lang)",\"target\":"(target==""?"null":q(target))"}"
 count++;name="";block=""
}
{
 raw=$0;line=$0;sub(/\r$/,"",line)
 if(fence){if(line=="```"){fence=0;if(name!="")emit();else if(!seen){if(header!="")bad("multiple section header blocks");header=block}block=""}else block=block raw"\n";next}
 if(line ~ /^## /){if(name!="")emit();heading=line;header="";seen=0}
 if(line ~ /^- \[[ x]\] [A-Za-z_][A-Za-z0-9_]*([[:space:]].*)?$/){
  if(name!="")emit()
  name=line;sub(/^- \[[ x]\] /,"",name);sub(/[[:space:]].*$/,"",name)
  description=line;sub(/^- \[[ x]\] [A-Za-z_][A-Za-z0-9_]*/,"",description);sub(/^[[:space:]]*(—|-)?[[:space:]]*/,"",description)
  if(names[name]++)bad("duplicate plan entry: "name)
  checked=(substr(line,4,1)=="x"?"true":"false");seen=1
 }else if(line ~ /^[[:space:]]*[-*+][[:space:]]+\[[^]]*\]/)bad("malformed plan entry: "line)
 if(line ~ /^```[A-Za-z0-9_-]*[[:space:]]*$/){fence=1;lang=line;sub(/^```/,"",lang);sub(/[[:space:]]*$/,"",lang);block=""}
 else if(line ~ /^```/)bad("malformed code fence")
}
END{if(failed)exit 1;if(fence)bad("unclosed code block in plan");if(name!="")emit()}
