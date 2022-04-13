on_fail() {
  echo ""
  echo "We are very sorry. Something went wrong."
  echo "Command '$previous_command' exited erroneous on line $1."
  echo "If you need help solving the issue ask for help on"
  echo "https://github.com/cloudradar-monitoring/rportd-installer/discussions/categories/help-needed"
  echo ""
}
debug() {
  previous_command=$this_command
  this_command=$BASH_COMMAND
}
trap 'debug' DEBUG
trap 'on_fail ${LINENO}' ERR
