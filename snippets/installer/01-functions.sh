#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  fqdn_is_public
#   DESCRIPTION:  Check if a FQDN is publicly resolvable through the cloudflare DNS over HTTP
#                 see https://developers.cloudflare.com/1.1.1.1/encryption/dns-over-https/
#    PARAMETERS:  FQDN
#       RETURNS:  exit code 0 if query resolves, 1 otherwise
#----------------------------------------------------------------------------------------------------------------------
fqdn_is_public() {
  if curl -fs -H 'accept: application/dns-json' "https://cloudflare-dns.com/dns-query?name=${1}" | grep -q '"Status":0'; then
    return 0
  else
    return 1
  fi
}

set_fqdn() {
  FQDN=$(echo "$1"| tr '[:upper:]' '[:lower:]')
  PUBLIC_FQDN=0
  if fqdn_is_public "${FQDN}"; then
    PUBLIC_FQDN=1
  else
    throw_info "FQDN ${FQDN} seems to be privat or local."
  fi
}

is_cloud_vm() {
  if [ -e /etc/cloud/digitalocean.info ]; then
    throw_debug "Installing on DigitalOcean"
    return 0
  fi

  if [ -e /etc/cloud-release ] && grep -q azure /etc/cloud-release; then
    throw_debug "Installing on Microsoft Azure"
    return 0
  fi

  if [ -e /etc/default/grub ] && grep -q vultr /etc/default/grub; then
    throw_debug "Installing on Vultr"
    return 0
  fi

  if [ -e /etc/cloud-release ] && grep -q ec2 /etc/cloud-release; then
    throw_debug "Installing on AWS EC2"
    return 0
  fi

  if [ -e /etc/boto.cfg ] && grep -q GoogleCompute /etc/boto.cfg; then
    throw_debug "Installing on Google GCE"
    return 0
  fi

  if [ -e /etc/scw-kernel-check.conf ] && grep -q Scaleway /etc/scw-kernel-check.conf; then
    throw_debug "Installing on Scaleway"
    return 0
  fi

  if [ -e /etc/cloud/cloud.cfg.d/90_dpkg.cfg ] && grep -q Hetzner /etc/cloud/cloud.cfg.d/90_dpkg.cfg; then
    throw_debug "Installing on Hetzner Cloud"
    return 0
  fi

  if command -v dmidecode >/dev/null 2>&1; then
    BIOS_VENDOR=$(dmidecode -s bios-vendor)
  else
    return 1
  fi
  case $BIOS_VENDOR in
  DigitalOcean)
    throw_debug "Installing on DigitalOcean"
    return 0
    ;;
  Hetzner)
    throw_debug "Installing on Hetzner"
    return 0
    ;;
  esac
  return 1
}

get_public_ip() {
  if [ -z "$MY_IP" ]; then
    MY_IP=$(curl -s 'https://api.ipify.org?format=text')
    if [ -z "$MY_IP" ]; then
      throw_error "Determining your public IP address failed."
      throw_hint "Make sure https://api.ipify.org is not blocked"
      false
    fi
    throw_debug "Your public IP address ${MY_IP}."
  fi
}

is_behind_nat() {
  if [ "$USES_NAT" -eq 0 ]; then
    # Skip the check if user has negated NAT explicitly.
    throw_debug "NAT check disabled."
    return 1
  fi

  if is_cloud_vm; then
    # Skip the check on well-known cloud providers.
    return 1
  fi
  get_public_ip
  if ip a | grep -q "$MY_IP"; then
    throw_info "Public IP address directly bound to the system."
    USES_NAT=0
    return 1
  else
    throw_info "System uses NAT"
    USES_NAT=1
    return 0
  fi
}

rejects_pings() {
  get_public_ip
  if ping -c1 -W2 -q "$MY_IP" >/dev/null 2>&1; then
    return 1
  else
    return 0
  fi
}

is_free_port() {
  TEST=$(nc -z -w 1 127.0.0.1 "$1" -v 2>&1)
  if echo "$TEST" | grep -q "connect to 127.0.0.1.*Connection refused"; then
    return 0
  elif echo "$TEST" | grep -q succeeded; then
    throw_error "Port $1 is in use."
    return 1
  elif [ "$1" -lt 65536 ]; then
    if timeout 5 bash -c "</dev/tcp/127.0.0.1/${1}" &>/dev/null; then
      throw_error "Port $1 is in use."
      return 1
    else
      return 0
    fi
  else
    throw_error "$1 is not valid TCP port."
    false
  fi
}

set_api_port() {
  throw_info "Setting API_PORT to $1"
  if is_free_port "$1"; then
    API_PORT=$1
  else
    throw_fatal "Setting API_PORT to $1 failed."
  fi
}

set_client_port() {
  throw_info "Setting CLIENT_PORT to $1"
  if is_free_port "$1"; then
    CLIENT_PORT="$1"
  else
    throw_error "Setting CLIENT_PORT failed."
    exit 1
  fi
}

set_tunnel_port_range() {
  if echo "$1" | grep -q -E "^[0-9]+\-[0-9]+$"; then
    throw_debug "Using tunnel port range $1"
    TUNNEL_PORT_RANGE=$1
  else
    throw_fatal "Invalid port range $1. Specify two integers separated by a dash. Example '10000-100100'."
  fi
}

set_client_url() {
  if echo "$1" | grep -E -q "^https?:\/\/[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$"; then
    throw_debug "Setting client connect URL $1"
    CLIENT_URL=$1
    if LANG=en curl -m4 -vsSI "${CLIENT_URL}" 2>&1 | grep -q "Could not resolve host"; then
      throw_fatal "Could not resolve host of ${CLIENT_URL}. Register the hostname on your DNS first."
    fi
  else
    throw_fatal "$1 is not valid URL of scheme http(s)://<HOST>(:<PORT>)"
  fi
}
