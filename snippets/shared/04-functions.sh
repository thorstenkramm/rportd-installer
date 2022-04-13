#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  is_terminal
#   DESCRIPTION:  check the scripts is executed on a terminal that allows interactive input
#    PARAMETERS:  ?
#       RETURNS:  exit code 0 un success (aka. is terminal), 1 otherwise
#----------------------------------------------------------------------------------------------------------------------
is_terminal() {
  if echo "$TERM" | grep -q "^xterm" && [ -n "$COLUMNS" ]; then
    return 0
  else
    echo 1>&2 "You are not on an interactive terminal. Please use command line switches to avoid interactive questions."
    return 1
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  progress
#   DESCRIPTION:  Reads a pipe and prints a # for each line received. Pipe is stored to a log file
#    PARAMETERS:  reads pipe
#       RETURNS:
#----------------------------------------------------------------------------------------------------------------------
progress() {
  if [ -z "$1" ]; then
    echo "function: progress(); Log file missing"
    return 1
  fi
  LOG_FILE=$1
  COUNT=1
  test -e "$LOG_FILE" && rm -f "$LOG_FILE"
  [ -z "$COLUMNS" ] && COLUMNS=120
  while read -r LINE; do
    echo -n "#"
    echo "$LINE" >>"$LOG_FILE"
    if [ $COUNT -eq $COLUMNS ]; then
      echo -e "\r"
      COUNT=0
    fi
    ((COUNT += 1))
  done
  echo ""
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  confirm
#   DESCRIPTION:  Ask interactively for a confirmation
#    PARAMETERS:  Text to ask
#       RETURNS:
#----------------------------------------------------------------------------------------------------------------------
confirm() {
  if [ -z "$1" ]; then
    echo -n "Do you want to proceed?"
  else
    echo -n "$1"
  fi
  echo " (y/n)"
  while read -r INPUT; do
    if echo "$INPUT" | grep -q "^[Yy]"; then
      return 0
    else
      return 1
    fi
  done
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  ask_for_email
#   DESCRIPTION:  interactively ask for an email and store it to the global EMAIL variable.
#    PARAMETERS:
#       RETURNS:
#----------------------------------------------------------------------------------------------------------------------
ask_for_email() {
  if ! is_terminal; then
    throw_fatal "use --email <EMAIL> to specify an email for 2fa or select another 2fa method."
  fi
  echo "Please enter your email address:"
  while read -r INPUT; do
    unset EMAIL
    if echo "$INPUT" | grep -q ".*@.*\.[a-z A-Z]"; then
      EMAIL=$INPUT
      if confirm "Is ${EMAIL} your correct email address?"; then
        return 0
      else
        echo "Please enter your email address:"
      fi
    else
      echo "ERROR: This is not a valid email. Try again or abort with CTRL-C"
      echo "Please enter your email address:"
    fi
  done
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  set_email
#   DESCRIPTION:  validate the input for a valid email and store in the global EMAIL variable on success.
#    PARAMETERS:  (string) email
#       RETURNS:
#----------------------------------------------------------------------------------------------------------------------
set_email() {
  if echo "$1" | grep -q ".*@.*\.[a-z A-Z]"; then
    EMAIL=$1
    throw_info "Your email is \"$EMAIL\""
  else
    throw_fatal "\"$1\" is not a valid email address"
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  is_available
#   DESCRIPTION:  Check if a command is available on the system.
#    PARAMETERS:  command name
#       RETURNS:  0 if available, 1 otherwise
#----------------------------------------------------------------------------------------------------------------------
is_available() {
  if command -v "$1" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  uninstall
#   DESCRIPTION:  Uninstall everything and remove the user
#----------------------------------------------------------------------------------------------------------------------
uninstall() {
  throw_info "Uninstalling the rport server ..."
  systemctl stop rportd >/dev/null 2>&1 || true
  rc-service rportd stop >/dev/null 2>&1 || true
  pkill -9 rportd >/dev/null 2>&1 || true
  rport --service uninstall >/dev/null 2>&1 || true
  FILES="/usr/local/bin/rportd
/etc/systemd/system/rportd.service
/etc/init.d/rportd
/usr/local/bin/2fa-sender.sh"
  for FILE in $FILES; do
    if [ -e "$FILE" ]; then
      rm -f "$FILE"
      throw_debug "Deleted file $FILE"
    fi
  done
  if id rport >/dev/null 2>&1; then
    if is_available deluser; then
      deluser rport
    elif is_available userdel; then
      userdel -r -f rport
    fi
    if groups rport >/dev/null 2>&1 && is_available groupdel; then
      groupdel -f rport
    fi
    throw_debug "Deleted user adn group 'rport'"
  fi
  FOLDERS="/etc/rport
/var/log/rport
/var/lib/rport"
  for FOLDER in $FOLDERS; do
    if [ -e "$FOLDER" ]; then
      rm -rf "$FOLDER"
      throw_debug "Deleted folder $FOLDER"
    fi
  done
  uninstall_guacd
  throw_info "RPort Server and it's components uninstalled."
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  uninstall_guacd
#   DESCRIPTION:  Uninstall the guacamole proxy daemon if present
#    PARAMETERS:  ?
#       RETURNS:
#----------------------------------------------------------------------------------------------------------------------
uninstall_guacd() {
  if ! command -v dpkg >/dev/null; then return; fi
  if ! dpkg -l | grep -q rport-guacamole; then return; fi
  throw_debug "Purging rport-guacamole package"
  apt-get -y remove --purge rport-guacamole
  throw_info "Consider running 'apt-get auto-remove' do clean up your system."
}

# Num  Colour    #define         R G B
#0    black     COLOR_BLACK     0,0,0
#1    red       COLOR_RED       1,0,0
#2    green     COLOR_GREEN     0,1,0
#3    yellow    COLOR_YELLOW    1,1,0
#4    blue      COLOR_BLUE      0,0,1
#5    magenta   COLOR_MAGENTA   1,0,1
#6    cyan      COLOR_CYAN      0,1,1
#7    white     COLOR_WHITE     1,1,1
#tput setab [1-7] # Set the background colour using ANSI escape
#tput setaf [1-7] # Set the foreground colour using ANSI escape
#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  throw_error
#   DESCRIPTION:  prints to stderr of the console
#    PARAMETERS:  text to be printed
#       RETURNS:
#----------------------------------------------------------------------------------------------------------------------
throw_error() {
  echo 2>&1 "$(tput setab 1)$(tput setaf 7)[!]$(tput sgr 0) $1"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  throw_fatal
#   DESCRIPTION:  prints to stderr of the console
#    PARAMETERS:  text to be printed
#       RETURNS:  false, which usually ends a script run with "-e"
#----------------------------------------------------------------------------------------------------------------------
throw_fatal() {
  echo 2>&1 "[!] $1"
  echo "[=] Fatal Exit. Don't give up. Good luck with the next try."
  false
}

throw_hint() {
  echo "[>] $1"
}

throw_info() {
  echo "$(tput setab 2)$(tput setaf 7)[*]$(tput sgr 0) $1"
}

throw_warning() {
  echo "[:] $1"
}

throw_debug() {
  echo "$(tput setab 4)$(tput setaf 7)[-]$(tput sgr 0) $1"
}

local_ip() {
  IP=$(awk '/32 host/ { print f } {f=$2}' <<<"$(</proc/net/fib_trie)" | grep -E "^(10|192.168|172.16)" | head -n1)
  [ -z "$IP" ] && return 1
  echo "$IP"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  external_ip
#   DESCRIPTION:  get the first external aka public IP Address if system has one
#    PARAMETERS:
#       RETURNS:  (string) IP address
#----------------------------------------------------------------------------------------------------------------------
external_ip() {
  IP=$(awk '/32 host/ { print f } {f=$2}' <<<"$(</proc/net/fib_trie)" | grep -E -v "^(10|192.168|172.16)" | head -n1)
  [ -z "$IP" ] && return 1
  echo "$IP"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  install_guacd
#   DESCRIPTION:  Install the guacamole daemon guacd if the rportd version and the distribution supports it
#    PARAMETERS:  ?
#       RETURNS:
#----------------------------------------------------------------------------------------------------------------------
install_guacd() {
  if [ -d /opt/rport-guacamole ]; then
    throw_info "Guacamole Proxy for Rport already installed"
    return 1
  fi
  if grep -q '#guacd_address' "$CONFIG_FILE"; then
    true
  else
    # RPortd does not support guacamole proxy
    return 1
  fi
  if [ "$INSTALL_GUACD" -eq 0 ]; then
    throw_info "Skipping Guacamole Proxy installation."
    return 1
  fi

  if grep -q "^ID.*=debian$" /etc/os-release; then
    throw_info "Going to install the Guacamole Proxy Daemon for RPort using Debian/Ubuntu Packages"
  else
    throw_info "No packages for the Guacamole Proxy Daemon available for your OS. Skipping."
    return 1
  fi
  # shellcheck source=/dev/null
  . /etc/os-release
  GUACD_PKG=rport-guacamole_1.4.0_${ID}_${VERSION_CODENAME}_$(uname -m).deb
  GUACD_DOWNLOAD=https://bitbucket.org/cloudradar/rport-guacamole/downloads/${GUACD_PKG}
  throw_debug "Downloading $GUACD_PKG"
  cd /tmp
  curl -fLOSs "$GUACD_DOWNLOAD" || (throw_error "Download failed" && return 0)
  throw_debug "Installing ${GUACD_PKG} via apt-get"
  DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install ./"${GUACD_PKG}" | progress /tmp/guacd-install.log
  rm -f ./"${GUACD_PKG}"
  if grep -q "^E:" /tmp/guacd-install.log; then
    throw_error "Installation of guacd failed. See /tmp/guacd-install.log"
  else
    rm -f /tmp/guacd-install.log
  fi
  sleep 1
  if pgrep -c guacd >/dev/null; then
    throw_info "Guacamole Proxy Daemon for RPort installed."
    return 0
  else
    throw_error "Installation of Guacamole Proxy Daemon for RPort failed."
    return 1
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  activate_guacd
#   DESCRIPTION:  Activate the guacd in the rportd.conf
#    PARAMETERS:
#       RETURNS:
#----------------------------------------------------------------------------------------------------------------------
activate_guacd() {
  if grep -q -E "\sguacd_address =" "$CONFIG_FILE"; then
    throw_info "Guacamole Proxy Daemon already registered in ${CONFIG_FILE}"
    return 0
  fi
  sed -i "s|#guacd_address =.*|guacd_address = \"127.0.0.1:9445\"|g" "$CONFIG_FILE"
  systemctl restart rportd
  throw_debug "Guacamole Proxy Daemon registered in ${CONFIG_FILE}"
  echo "What's next"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  install_novnc
#   DESCRIPTION:  Install the NoVNC Javasript files by downloading from the github repo
#    PARAMETERS:  ?
#       RETURNS:
#----------------------------------------------------------------------------------------------------------------------
install_novnc() {
  if [ -d /var/lib/rport/noVNC-1.3.0 ]; then
    throw_info "NoVNC already installed"
    return 0
  fi
  if [ -n "$NOVNC_ROOT" ]; then
    NOVNC_DOWNLOAD='https://github.com/novnc/noVNC/archive/refs/tags/v1.3.0.zip'
    throw_debug "Downloading $NOVNC_DOWNLOAD"
    curl -LSs $NOVNC_DOWNLOAD -o /tmp/novnc.zip
    unzip -o -qq -d /var/lib/rport /tmp/novnc.zip
    rm -f /tmp/novnc.zip
    chown -R rport:rport "$NOVNC_ROOT"
    throw_info "NoVNC Addon installed to $NOVNC_ROOT"
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  activate_novnc
#   DESCRIPTION:  Make all changes to rportd.conf to activate NoVNC
#    PARAMETERS:  ?
#       RETURNS:
#----------------------------------------------------------------------------------------------------------------------
activate_novnc() {
  if grep -q -E "\snovnc_root =" "$CONFIG_FILE"; then
    throw_info "NoVNC already registered in ${CONFIG_FILE}"
    return 0
  fi
  NOVNC_ROOT='/var/lib/rport/noVNC-1.3.0'
  sed -i "s|#novnc_root =.*|novnc_root = \"${NOVNC_ROOT}\"|g" "$CONFIG_FILE"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  version_to_int
#   DESCRIPTION:  convert a semver version string to integer to be comparable mathematically
#    PARAMETERS:  semver string
#       RETURNS:  integer
#----------------------------------------------------------------------------------------------------------------------
version_to_int() {
  echo "$1" |
    awk -v 'maxsections=3' -F'.' 'NF < maxsections {printf("%s",$0);for(i=NF;i<maxsections;i++)printf("%s",".0");printf("\n")} NF >= maxsections {print}' |
    awk -v 'maxdigits=3' -F'.' '{print $1*10^(maxdigits*2)+$2*10^(maxdigits)+$3}'
}
