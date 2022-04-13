DOC_ROOT="/var/lib/rport/docroot"
test -e ${DOC_ROOT}&&rm -rf ${DOC_ROOT}
mkdir ${DOC_ROOT}
cd ${DOC_ROOT}
curl -LSs https://downloads.rport.io/frontend/${RELEASE}/latest.php -o rport-frontend.zip
unzip -qq rport-frontend.zip && rm -f rport-frontend.zip
cd ~
## Create a symbolic link of the ssl root-ca certificate so users can download the file with ease
if [ -n "$CA_CERT" ] && [ -e "$CA_CERT" ] ;then
  ln -s "$CA_CERT" ${DOC_ROOT}/rport-ca.crt
fi
chown -R rport:rport ${DOC_ROOT}
throw_info "The RPort Frontend has been installed from the latest ${RELEASE} release."

install_novnc