# Install the RPort Server
ARCH=$(uname -m | sed s/aarch64/arm64/)
DOWNLOAD_URL="https://download.rport.io/rportd/${RELEASE}/latest.php?arch=${ARCH}"
throw_debug "Downloading ${DOWNLOAD_URL}"
curl -LSs "${DOWNLOAD_URL}" -o rportd.tar.gz
tar vxzf rportd.tar.gz -C /usr/local/bin/ rportd
id rport >/dev/null 2>&1||useradd -d /var/lib/rport -m -U -r -s /bin/false rport
test -e /etc/rport||mkdir /etc/rport/
test -e /var/log/rport||mkdir /var/log/rport/
chown rport /var/log/rport/
tar vxzf rportd.tar.gz -C /etc/rport/ rportd.example.conf
cp /etc/rport/rportd.example.conf /etc/rport/rportd.conf

# Create a unique key for your instance
KEY_SEED=$(openssl rand -hex 18)
sed -i "s/key_seed = .*/key_seed =\"${KEY_SEED}\"/g" /etc/rport/rportd.conf

# Create a systemd service
/usr/local/bin/rportd --service install --service-user rport --config /etc/rport/rportd.conf||true
sed -i '/^\[Service\]/a LimitNOFILE=1048576' /etc/systemd/system/rportd.service
sed -i '/^\[Service\]/a LimitNPROC=512' /etc/systemd/system/rportd.service
systemctl daemon-reload
#systemctl start rportd
systemctl enable rportd
if /usr/local/bin/rportd --version;then
  true
else
  throw_fatal "Unable to start the rport server. Check /var/log/rport/rportd.log"
fi
rm rportd.tar.gz
echo "------------------------------------------------------------------------------"
throw_info "The RPort server has been installed from the latest ${RELEASE} release. "
echo ""
