#!/user/bin/env bash
set -e
echo "Starting test"

ADMIN_PASSWORD=$(grep Password /root/rportd-installation.txt |awk '{print $2}')
echo "Admin password $ADMIN_PASSWORD found."

if grep -q rportd.localnet.local /etc/hosts;then
    true
else
    echo "127.0.0.2 rportd.localnet.local">>/etc/hosts
fi

# Rocky
if grep -q 'ID_LIKE="rhel' /etc/os-release;then
    cp /etc/rport/ssl/ca/export/rport-ca.crt /usr/share/pki/ca-trust-source/anchors/
    update-ca-trust extract
fi
# Debian Ubuntu
if grep -E "ID=(debian|ubuntu)" /etc/os-release;then
    cp -f /etc/rport/ssl/ca/export/rport-ca.crt /usr/local/share/ca-certificates/rport-ca.crt
    update-ca-certificates
fi

URL=https://rportd.localnet.local/api/v1
curl -sfI ${URL}
curl -fs -u admin:"${ADMIN_PASSWORD}" ${URL}/login
echo ""
echo "🎰 BINGO. Test finished"