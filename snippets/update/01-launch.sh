help() {
  cat <<EOF
Usage $0 [OPTION(s)]

Update the rport server

Options:
-h,--help  Print this help message
-t,--unstable  Use the latest unstable version (DANGEROUS!)
-g,--skip-guacd Do not install the Guacamole Proxy Daemon needed for RDP over web.

EOF
}

#
# Read the command line options and map to a function call
#
RELEASE=stable
TEMP=$(getopt -o vhtg --long version,help,unstable,skip-guacd -- "$@")
if [ $? -gt 0 ]; then
  help
  exit 1
fi
eval set -- "$TEMP"

INSTALL_GUACD=1
VERSION=0
# extract options and their arguments into variables.
while true; do
  case "$1" in
  -h | --help)
    help
    exit 0
    ;;
  -t | --unstable)
    RELEASE=unstable
    shift 1
    ;;
  -g | --skip-guacd)
    INSTALL_GUACD=0
    shift 1
    ;;
  -v | --version)
    echo "Version ${VERSION}"
    exit 0
    ;;
  --)
    shift
    break
    ;;
  *)
    echo "Internal error!"
    help
    exit 1
    ;;
  esac
done
