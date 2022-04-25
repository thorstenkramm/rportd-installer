#!/user/bin/env bash
set -e
echo "Starting test"

ADMIN_PASSWORD=$(grep Password /root/rportd-installation.txt | awk '{print $2}')
echo "Admin password $ADMIN_PASSWORD found."

# Enable 2fa debug log to grab the token
echo "LOG_LEVEL=debug" >/etc/rport/2fa-sender.conf
# Prevent real sending of email
sed "s/# Trigger.*/log dummy;exit 0/g" -i /usr/local/bin/2fa-sender.sh

if grep -q rportd.localnet.local /etc/hosts; then
  true
else
  echo "127.0.0.2 rportd.localnet.local" >>/etc/hosts
fi

# Rocky
if grep -q 'ID_LIKE="rhel' /etc/os-release; then
  cp /etc/rport/ssl/ca/export/rport-ca.crt /usr/share/pki/ca-trust-source/anchors/
  update-ca-trust extract
fi
# Debian Ubuntu
if grep -E "ID=(debian|ubuntu)" /etc/os-release; then
  cp -f /etc/rport/ssl/ca/export/rport-ca.crt /usr/local/share/ca-certificates/rport-ca.crt
  update-ca-certificates
fi

URL=https://rportd.localnet.local/api/v1
curl -sfI ${URL}
# Request the 2FA Token
# Returns a JWT needed for /verify-2fa
curl -fs -u admin:"${ADMIN_PASSWORD}" ${URL}/login -o auth.json
test -e auth.json

MFA_TOKEN=$(grep -Eo "TOKEN=[A-Z a-z 0-9]*" /var/log/rport/2fa-sender.log | tail -n1 | cut -d= -f2)
TOKEN=$(jq -r .data.token < auth.json)
if [ -z "$MFA_TOKEN" ]; then
  echo "Test failed. No 2FA token found"
  cat /var/log/rport/2fa-sender.log
  false
fi
curl -s "${URL}/verify-2fa?token-lifetime=7200" \
-H "Authorization: Bearer $TOKEN" \
-H "Content-Type: application/json" -X POST \
--data-raw "{\"username\": \"admin\",\"token\": \"${MFA_TOKEN}\"}" -o finalauth.json
test -e finalauth.json

# Update the TOKEN var needed for further requests
TOKEN=$(jq -r .data.token < finalauth.json)

# Get the list of clients
curl -fs -H "Authorization: Bearer $TOKEN" ${URL}/clients

echo ""
echo "🎰 BINGO. Test finished"
