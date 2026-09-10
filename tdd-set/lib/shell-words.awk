# A non-evaluating shell-word reader for direct Test commands. NUL-delimited argv.
function fail(s){print s > "/dev/stderr";bad=1;exit 1}
function emit(){if(have){printf "%s%c",word,0;word="";have=0}}
{ if(NR>1)fail("multiline Test command is unsupported")
 for(i=1;i<=length($0);i++){
  c=substr($0,i,1)
  if(escape){word=word c;escape=0;have=1;continue}
  if(quote=="\047"){if(c==quote)quote="";else word=word c;continue}
  if(c=="\\"){escape=1;have=1;continue}
  if(quote=="\""){if(c==quote)quote="";else if(c=="$" || c=="`")fail("Test command expansion is unsupported");else word=word c;continue}
  if(c=="\047" || c=="\""){quote=c;have=1;continue}
  if(c ~ /[[:space:]]/){emit();continue}
  if(c ~ /[;&|<>`$]/)fail("unsupported Test command shell operators")
  word=word c;have=1
 }
}
END{if(bad)exit 1;if(quote!=""||escape)fail("unterminated Test command quote");emit()}
