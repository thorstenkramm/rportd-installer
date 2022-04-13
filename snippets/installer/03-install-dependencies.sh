#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  install_dependencies
#   DESCRIPTION:  For the installation we need some tools, let's install them quickly..
#    PARAMETERS:
#       RETURNS:
#----------------------------------------------------------------------------------------------------------------------
install_dependencies() {
  DEP_INSTALL_LOG="/tmp/rportd-install-dependencies.log"
  echo "$(date) -- installing rportd dependencies" >$DEP_INSTALL_LOG
  RPM_DEPS=(unzip sqlite nmap-ncat httpd-tools tar)
  DEB_DEPS=(pwgen apache2-utils unzip curl sqlite3 netcat)
  if [ "$API_PORT" -eq 443 ]; then
    DEB_DEPS+=(certbot)
    RPM_DEPS+=(certbot)
  fi
  throw_info "Installing Dependencies ... be patient."
  if is_available apt-get; then
    throw_debug "The following packages will be installed: ${DEB_DEPS[*]}"
    apt-get -y update
    DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install "${DEB_DEPS[@]}"  2>&1| progress $DEP_INSTALL_LOG
  elif is_available dnf; then
    throw_debug "Installing dependencies using dfn."
    throw_debug "The following packages will be installed: ${RPM_DEPS[*]}"
    dnf -y install "${RPM_DEPS[@]}"
  elif is_available yum; then
    throw_debug "Installing dependencies using yum."
    throw_debug "The following packages will be installed: ${RPM_DEPS[*]}"
    yum -y install "${RPM_DEPS[@]}"
  else
    throw_fatal "No supported package manager found. 'apt-get', 'dfn' or 'yum' required."
  fi
  if grep -q "^E:" $DEP_INSTALL_LOG; then
    throw_fatal "Installing dependencies failed. See $DEP_INSTALL_LOG"
  else
    #rm -f "$DEP_INSTALL_LOG"
    throw_info "Dependencies installed."
  fi
}
install_dependencies
## Prepare the UFW firewall if present
if command -v ufw >/dev/null 2>&1; then
  throw_info "UFW firewall detected. Adding rules now."
  throw_debug "Allowing API Port ${API_PORT}"
  ufw allow "${API_PORT}"/tcp
  throw_debug "Allowing Client Port ${CLIENT_PORT}"
  ufw allow "${CLIENT_PORT}"/tcp
  throw_debug "Allowing Tunnel Port Range ${TUNNEL_PORT_RANGE}"
  ufw allow "$(echo "${TUNNEL_PORT_RANGE}" | tr - :)"/tcp
fi
