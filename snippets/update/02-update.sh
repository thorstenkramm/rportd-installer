#
# Update of the RPort Server
#
if [ -e /usr/local/bin/rportd ];then
  CURRENT_VERSION=$(/usr/local/bin/rportd --version | awk '{print $2}')
else
  throw_fatal "No rportd binary found in /usr/local/bin/rportd"
fi

cd /tmp
ARCH=$(uname -m | sed s/"armv\(6\|7\)l"/"armv\1"/ | sed s/aarch64/arm64/)
URL="https://download.rport.io/rportd/${RELEASE}/?arch=Linux_${ARCH}&gt=${CURRENT_VERSION}"
curl -Ls "${URL}" -o rportd.tar.gz
test -e rportd && rm -f rportd
if tar xzf rportd.tar.gz rportd 2>/dev/null; then
  TARGET_VERSION=$(./rportd --version | awk '{print $2}')
  rm rportd.tar.gz
else
  rm rportd.tar.gz
  throw_info "Nothing to do. RPortd is on the latest version ${CURRENT_VERSION}."
  exit 0
fi

systemctl stop rportd

# Create a backup
FOLDERS=(/usr/local/bin/rportd /var/lib/rport /var/log/rport /etc/rport)
throw_info "Creating a backup of your RPort data. This can take a while."
throw_debug "${FOLDERS[*]} will be backed up."
BACKUP_FILE=/var/backups/rportd-$(date +%Y%m%d-%H%M%S).tar.gz
throw_info "Be patient! The backup might take minutes or half an hour depending on your database sizes."
if is_available pv; then
  EST_SIZE=$(du -sb /var/lib/rport | awk '{print $1}')
  tar cf - "${FOLDERS[@]}" | pv -s "$EST_SIZE" | gzip > "$BACKUP_FILE"
else
  tar cvzf "$BACKUP_FILE" "${FOLDERS[@]}"
fi

throw_info "A backup has been created in $BACKUP_FILE"
# Update server
mv rportd /usr/local/bin/rportd

# After each update you need to allow binding to privileged ports
setcap CAP_NET_BIND_SERVICE=+eip /usr/local/bin/rportd
throw_info "/usr/local/bin/rportd updated to version $TARGET_VERSION"

# If you come from a old versions create columns if missing.
# Ignore the errors if the columns exist.
throw_info "Performing database migrations where needed."
if [ -e /var/lib/rport/user-auth.db ]; then
  sqlite3 /var/lib/rport/user-auth.db \
  'ALTER TABLE "users" ADD column "token" TEXT(36) DEFAULT NULL' 2>/dev/null ||true
  sqlite3 /var/lib/rport/user-auth.db \
  'ALTER TABLE "users" ADD column "two_fa_send_to" TEXT(150) DEFAULT NULL' 2>/dev/null ||true
  sqlite3 /var/lib/rport/user-auth.db \
  'ALTER TABLE "users" ADD column "totp_secret" TEXT DEFAULT ""' 2>/dev/null ||true
fi
# Activate the new reverse proxy feature
CONFIG_FILE=/etc/rport/rportd.conf

activate_proxy() {
  if grep -q tunnel_proxy_cert_file $CONFIG_FILE; then
    throw_info "Reverse Proxy already activated"
    return 0
  fi
  CERT_FILE=$(grep "^\W*cert_file =" $CONFIG_FILE|sed -e "s/cert_file = \"\(.*\)\"/\1/g"|tr -d " ")
  KEY_FILE=$(grep "^\W*key_file =" $CONFIG_FILE|sed -e "s/key_file = \"\(.*\)\"/\1/g"|tr -d " ")

  if [ -e "$CERT_FILE" ] && [ -e "$KEY_FILE" ];then
      throw_debug "Key and certificate found."
      sed -i "/^\[server\]/a \ \ tunnel_proxy_cert_file = \"$CERT_FILE\"" $CONFIG_FILE
      sed -i "/^\[server\]/a \ \ tunnel_proxy_key_file = \"$KEY_FILE\"" $CONFIG_FILE
      throw_info "Reverse proxy activated"
  fi
}
activate_proxy

# Enable monitoring
activate_monitoring() {
  if grep -q "\[monitoring\]" $CONFIG_FILE; then
      throw_info "Monitoring is already enabled."
      return 0
  fi
  echo '
[monitoring]
  ## The rport server stores monitoring data of the clients for N days.
  ## https://oss.rport.io/docs/no17-monitoring.html
  ## Older data is purged automatically.
  ## Default: 30 days
  data_storage_days = 7
  '>> $CONFIG_FILE
  throw_info "Monitoring enabled."
}
activate_monitoring

# Update the frontend
cd /var/lib/rport/docroot/
rm -rf ./*
curl -Ls https://downloads.rport.io/frontend/${RELEASE}/latest.php -o rport-frontend.zip
unzip -o -qq rport-frontend.zip && rm -f rport-frontend.zip
chown -R rport:rport /var/lib/rport/docroot/
FRONTEND_VERSION=$(sed s/rport-frontend-//g < /var/lib/rport/docroot/version.txt)
throw_info "Frontend updated to ${FRONTEND_VERSION}"
if [ "$(version_to_int "$TARGET_VERSION")" -gt 5019 ];then
  # Install guacamole proxy
  sed -i "/^\[logging\]/i \ \ #guacd_address = \"127.0.0.1:8442\"\n" $CONFIG_FILE
  install_guacd && activate_guacd
  # Install NoVNC JS
  if [ -e /var/lib/rport ];then
    install_novnc
    activate_novnc
  fi
fi
# Start the server
systemctl start rportd
throw_info "You are now using RPort Server $TARGET_VERSION (Frontend ${FRONTEND_VERSION})"