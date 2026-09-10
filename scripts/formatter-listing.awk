# Tokenize a declared shell command without evaluating it. Recognize gofmt's
# listing flag before positional paths, including a quoted/absolute executable.
{ source = source $0 "\n" }
END {
  quote=""; escaped=0; word=""; started=0; count=0
  for (i=1; i<=length(source); i++) {
    c=substr(source,i,1)
    if (escaped) { word=word c; started=1; escaped=0; continue }
    if (quote==sprintf("%c",39)) {
      if (c==quote) quote=""; else word=word c
      continue
    }
    if (c=="\\") { escaped=1; started=1; continue }
    if (quote=="\"") {
      if (c==quote) quote=""; else word=word c
      continue
    }
    if (c=="\"" || c==sprintf("%c",39)) { quote=c; started=1; continue }
    if (c ~ /[[:space:]]/) {
      if (started) { words[++count]=word; word=""; started=0 }
      continue
    }
    word=word c; started=1
  }
  if (started) words[++count]=word
  executable=words[1]; sub(/^.*\//,"",executable)
  if (executable!="gofmt") exit 1
  for (i=2; i<=count; i++) {
    option=words[i]
    if (option=="--" || option !~ /^-/) break
    if (option=="-r" || option=="--r" || option=="-cpuprofile" || option=="--cpuprofile") {i++; continue}
    if (option=="--l" || (option ~ /^-[sldew]+$/ && index(option,"l"))) exit 0
  }
  exit 1
}
