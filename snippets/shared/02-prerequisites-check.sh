if ! uname -o |grep -qi linux ; then
  echo "This installer runs on Linux only."
  exit 1
fi

if [[ $SHELL =~ bash ]] 2>/dev/null;then
    true
else
    2>&1 echo "Execute with bash. Exit."
    exit 1
fi

if id|grep -q uid=0; then
  true
else
  echo "This installer needs to be run with root rights."
  echo "Change to the root account or execute"
  echo "sudo $0 $*"
  false
fi
[ "$TERM" = 'dumb' ]||[ -z "$TERM" ]&&export TERM=xterm-256color