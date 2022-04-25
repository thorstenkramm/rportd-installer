enable_email_2fa() {
  cat << 'EOF' >/usr/local/bin/2fa-sender.sh
#!/bin/bash
#
# This is a script for sending two factor auth token via a free API provided by cloudradar GmbH
# Check https://kb.rport.io/install-the-rport-server/enable-two-factor-authentication
# and learn how to use your own SMTP server or alternative delivery methods
#

# Source a configuration if available
CONF="/etc/rport/2fa-sender.conf"
[ -e "$CONF" ] && . $CONF

log() {
  [ -z "$LOG_LEVEL" ] && return 0
  [ -z "$LOG_FILE" ] && LOG_FILE="/var/log/rport/2fa-sender.log"
  LOG_LINE=("$(date) -- Token sent to ${RPORT_2FA_SENDTO}; ")
  if [ $LOG_LEVEL = 'debug' ];then
    LOG_LINE+=("TOKEN=${RPORT_2FA_TOKEN}; ")
  fi
  LOG_LINE+=("Response: $1")
  echo ${LOG_LINE[*]}>>"$LOG_FILE"
}


# Trigger sending the email via a public API
RESPONSE=$(curl -Ss https://free-2fa-sender.rport.io \
 -F email=${RPORT_2FA_SENDTO} \
 -F token=${RPORT_2FA_TOKEN} \
 -F ttl=${RPORT_2FA_TOKEN_TTL} \
 -F url="_URL_" 2>&1)
if echo $RESPONSE|grep -q "Message sent";then
    echo "Token sent via email"
    log "Message sent"
    exit 0
else
    >&2 echo $RESPONSE
    log "Error \"$RESPONSE\""
    exit 1
fi
EOF
  sed -i "s|_URL_|https://${FQDN}:${API_PORT}|g" /usr/local/bin/2fa-sender.sh
  chmod +x /usr/local/bin/2fa-sender.sh
  sed -i "s|#two_fa_token_delivery.*|two_fa_token_delivery = \"/usr/local/bin/2fa-sender.sh\"|g" /etc/rport/rportd.conf
  sed -i "s|#two_fa_send_to_type.*|two_fa_send_to_type = \"email\"|g" /etc/rport/rportd.conf
  TWO_FA_MSG="After the log in, check the inbox of ${EMAIL} to get the two-factor token."
  systemctl restart rportd
  throw_info "${TWO_FA}-based two factor authentication installed."
}

enable_totp_2fa() {
  sed -i "s|#totp_enabled.*|totp_enabled = true|g" /etc/rport/rportd.conf
  sed -i "s|#totp_login_session_ttl|totp_login_session_ttl|g" /etc/rport/rportd.conf
  TWO_FA_MSG="After the log in, you must set up your TOTP authenticator app."
  systemctl restart rportd
  throw_info "${TWO_FA}-based two factor authentication installed."
}

if [ "$TWO_FA" == 'none' ]; then
  throw_info "Two factor authentication NOT installed."
elif [ "$TWO_FA" == 'totp' ]; then
    enable_totp_2fa
elif nc -v -w 1 -z free-2fa-sender.rport.io 443 2>/dev/null;then
  throw_debug "Connection to free-2fa-sender.rport.io port 443 succeeded."
  enable_email_2fa
else
  throw_info "Outgoing https connections seem to be blocked."
  throw_waring "Two factor authentication NOT installed."
fi