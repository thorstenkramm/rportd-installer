systemctl stop rportd
CONFIG_FILE='/etc/rport/rportd.conf'
#
# Change the default config.
#
if [ -z "$CLIENT_URL" ];then
  CLIENT_URL=http://${FQDN}:${CLIENT_PORT}
fi
sed -i "s/#address = .*/address = \"0.0.0.0:${CLIENT_PORT}\"/g" $CONFIG_FILE
# Set the url(s) where client can connect to
if grep -q "Optionally defines full client connect URL(s)." $CONFIG_FILE;then
  # New style, set a list
  sed -i "s|#url = .*|url = [\"${CLIENT_URL}\"]|g" $CONFIG_FILE
else
  # Old style, single value
  sed -i "s|#url = .*|url = \"${CLIENT_URL}\"|g" $CONFIG_FILE
fi

sed -i "s/auth = \"clientAuth/#auth = \"clientAuth\"/g" $CONFIG_FILE
sed -i "s|#auth_file.*client-auth.json|auth_file = \"/var/lib/rport/client-auth.json|g" $CONFIG_FILE
sed -i "s/address = \"0.0.0.0:3000\"/address = \"0.0.0.0:${API_PORT}\"/g" $CONFIG_FILE
sed -i "s/auth = \"admin:foobaz\"/#auth = \"admin:foobaz\"/g" $CONFIG_FILE
sed -i "s/#auth_user_table/auth_user_table/g" $CONFIG_FILE
sed -i "s/#auth_group_table/auth_group_table/g" $CONFIG_FILE
sed -i "s/#db_type = \"sqlite\"/db_type = \"sqlite\"/g" $CONFIG_FILE
sed -i "s|#db_name = \"/var.*|db_name = \"$DB_FILE\"|g" $CONFIG_FILE
sed -i "s|#used_ports = .*|used_ports = ['${TUNNEL_PORT_RANGE}']|g" $CONFIG_FILE
sed -i "s/jwt_secret =.*/jwt_secret = \"$(pwgen 18 1 2>/dev/null||openssl rand -hex 9)\"/g" $CONFIG_FILE
# Enable SSL with the previously generated cert and key
sed -i "s|#cert_file =.*|cert_file = \"${SSL_CERT_FILE}\"|g" $CONFIG_FILE
sed -i "s|#key_file =.*|key_file = \"${SSL_KEY_FILE}\"|g" $CONFIG_FILE
# Enable the built-in tunnel proxy
sed -i "s|#tunnel_proxy_cert_file =.*|tunnel_proxy_cert_file = \"${SSL_CERT_FILE}\"|g" $CONFIG_FILE
sed -i "s|#tunnel_proxy_key_file =.*|tunnel_proxy_key_file = \"${SSL_KEY_FILE}\"|g" $CONFIG_FILE
sed -i "s/#doc_root/doc_root/g" $CONFIG_FILE
sed -i "s/totp_account_name = .*/totp_account_name = \"${FQDN}\"/g" $CONFIG_FILE
# Set longer retention period for disconnected clients
sed -i "s/#keep_lost_clients = .*/keep_lost_clients = \"168h\"/g" $CONFIG_FILE
# Set a shorter retention period for monitoring data
sed -i "s/#data_storage_days = .*/data_storage_days = 7/g" $CONFIG_FILE
#sed -i "s/#max_request_bytes/max_request_bytes = 10240/g" $CONFIG_FILE
# Activate the NoVNC proxy
##novnc_root = "/var/lib/rport/novncroot"
if grep -q novnc_root $CONFIG_FILE; then
  activate_novnc
fi
throw_debug "Configuration file $CONFIG_FILE written. "
sleep 0.3
[ -n "${ADMIN_PASSWD}" ] || ADMIN_PASSWD=$(pwgen 9 1 2>/dev/null||openssl rand -hex 5)
PASSWD_HASH=$(htpasswd -nbB password "$ADMIN_PASSWD"|cut -d: -f2)
## Create the database and the first user
test -e "$DB_FILE"&& rm -f "$DB_FILE"
touch "$DB_FILE"
chown rport:rport "$DB_FILE"
cat <<EOF|sqlite3 "$DB_FILE"
CREATE TABLE "users" (
  "username" TEXT(150) NOT NULL,
  "password" TEXT(255) NOT NULL,
  "token" TEXT(36) DEFAULT NULL,
  "two_fa_send_to" TEXT(150),
  "totp_secret" TEXT DEFAULT ""
);
CREATE UNIQUE INDEX "main"."username" ON "users" (
  "username" ASC
);
CREATE TABLE "groups" (
  "username" TEXT(150) NOT NULL,
  "group" TEXT(150) NOT NULL
);
CREATE UNIQUE INDEX "main"."username_group"
ON "groups" (
  "username" ASC,
  "group" ASC
);
INSERT INTO users VALUES('admin','$PASSWD_HASH',null,'$EMAIL','');
INSERT INTO groups VALUES('admin','Administrators');
EOF
throw_debug "RPort Database $DB_FILE created."
sleep 0.3
CLIENT_PASSWD=$(pwgen 18 1 2>/dev/null||openssl rand -hex 9)
## Create the first client credentials
cat > /var/lib/rport/client-auth.json <<EOF
{
    "client1": "$CLIENT_PASSWD"
}
EOF
chown rport:rport /var/lib/rport/client-auth.json
throw_debug "Client auth file /var/lib/rport/client-auth.json written."
sleep 0.3
setcap CAP_NET_BIND_SERVICE=+eip /usr/local/bin/rportd
systemctl start rportd
if [ -z "$(pgrep rportd)" ]; then
  echo "------------------------------------------------------------------------------"
  throw_error "Starting your RPort server failed."
  echo "      Go to https://rport.io/en/contact and ask for help."
  echo "      The following information might help."
  tail -n100 /var/log/rport/rportd.log
  su - rport -s /bin/bash -c "rportd -c $CONFIG_FILE"
  false
fi
sleep 3
