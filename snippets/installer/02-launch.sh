help() {
  cat <<EOF
Usage $0 [OPTION(s)]

Options:
-h,--help  Print this help message
-f,--force  Force, overwriting existing files and configurations
-t,--unstable  Use the latest unstable version (DANGEROUS!)
-e,--email {EMAIL}  Don't ask for the email interactively
-d,--fqdn {FQDN}  Use a custom FQDN. Otherwise a random FQDN on *.users.rport.io will be created.
-k,--skip-dnscheck Do not verify {FQDN} exists. Install anyway.
-u,--uninstall  Uninstall rportd and all related files
-c,--client-port {PORT} Use a different port than 80 for the client aka agent connections.
-i,--client-url {URL} Instruct clients to connect to this URL instead of {FQDN}
-a,--api-port {PORT} Use a different port than 443 for the API and the Web UI.
-s,--skip-nat Do not detect NAT and assume direct internet connection with public IP address (e.g. one-to-one NAT).
-o,--totp Use time-based one time passwords (TOTP) instead of email for two-factor authentication
-n,--no-2fa Disable two factor authentification
-p,--port-range ports dynamically used for active tunnels. Default 20000-30000
-g,--skip-guacd Do not install a version of the Guacamole Proxy Daemon needed for RDP over web.

Examples:
sudo bash $0 --email user@example.com
  Installs the RPort server with a randomly generated FQDN <RAND>.users.rport.io
  used for client connect, the API and the Web UI. Email-based two-factor authentication is enabled.

sudo bash $0 --no-2fa \\
  --fqdn rport.local.localnet \\
  --api-port 8443 \\
  --port-range 5000-5050 \\
  --client-url http://my-rport-server.dyndns.org:8080
  Installs the RPort server
    * with a fixed local FQDN.
    * Port 8443 is used for the user interface and the API.
    * Clients are expected outside the local network connecting over a port forwarding via a public FQDN.
    * No two factor authentication is used. (not recommended)
    * Self-signed certificates are generated because Let's encrypt denies using port 8443 for identity validation.
EOF
}

#
# Read the command line options and map to a function call
#
TEMP=$(getopt \
  -o vhta:sone:d:c:d:p:i:ug \
  --long version,help,unstable,fqdn:,email:,client-port:,api-port:,port-range:,client-url:,uninstall,skip-nat,skip-guacd,totp,no-2fa \
  -- "$@")
eval set -- "$TEMP"

RELEASE=stable
API_PORT=443
CLIENT_PORT=80
DB_FILE=/var/lib/rport/user-auth.db
DNS_CREATED=0
USES_NAT=2
TUNNEL_PORT_RANGE='20000-30000'
TWO_FA=email
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
  -d | --fqdn)
    set_fqdn "$2"
    shift 2
    ;;
  -e | --email)
    set_email "$2"
    shift 2
    ;;
  -u | --uninstall)
    uninstall
    exit 0
    ;;
  -c | --client-port)
    set_client_port "$2"
    shift 2
    ;;
  -i | --client-url)
    set_client_url "$2"
    shift 2
    ;;
  -a | --api-port)
    set_api_port "$2"
    shift 2
    ;;
  -s | --skip-nat)
    USES_NAT=0
    shift 1
    ;;
  -o | --totp)
    TWO_FA=totp
    EMAIL=user@example.com
    shift 1
    ;;
  -n | --no-2fa)
    TWO_FA=none
    shift 1
    ;;
  -p | --port-range)
    set_tunnel_port_range "$2"
    shift 2
    ;;
  -g | --skip-guacd)
    INSTALL_GUACD=0
    shift 1
    ;;
  -v | --version)
    echo "Version $VERSION"
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

if [ -e /etc/os-release ] && grep -q 'REDHAT_SUPPORT_PRODUCT_VERSION="7"' /etc/os-release; then
  throw_fatal "Sorry. RedHat/CentOS/Alma/Rocky Linux >=8 required."
fi

if [ -e /etc/os-release ] && grep -q '^REDHAT_SUPPORT_PRODUCT_VERSION=".*Stream"$' /etc/os-release; then
  throw_fatal "Sorry. CentOS Stream not supported yet."
fi

if [ -e /etc/os-release ] && grep -q "^ID_LIKE.*rhel" /etc/os-release; then
  if rpm -qa | grep -q epel-release; then
    true
  else
    throw_fatal "Please enable the epel-release and try again. Try 'dnf install epel-release'."
  fi
fi

if [ -z "$FQDN" ]; then
  if is_behind_nat; then
    # If machine is behind NAT we do not create a random FQDN, because the IP is very likely a dynamic one.
    throw_error "Random FQDNs are only generated for systems with a public IP address."
    throw_hint "If this system is behind a one-to-one NAT (Azure, AWS EC2, Scaleway, GPE) use '--skip-nat'"
    throw_hint "If your are behind a NAT with a dynamic IP address provide a FQDN with '--fqdn'"
    throw_fatal "NAT detected"
  fi

  if rejects_pings; then
    throw_hint "Check your firewall settings and allow incoming ICMP v4."
    throw_fatal "Pings denied. System does not respond to ICMP echo requests aka pings on the public IP address."
  fi
fi

if [ -z $EMAIL ] && [ $TWO_FA != 'none' ]; then
  bold=$(tput bold)
  normal=$(tput sgr0)
  echo ""
  echo " | RPort comes with two factor authentication enabled by default."
  echo " | To send the first 2fa-token a ${bold}valid email address is needed${normal}."
  echo " | Your email address will be stored only locally on this system inside the user database."
  ask_for_email
fi
