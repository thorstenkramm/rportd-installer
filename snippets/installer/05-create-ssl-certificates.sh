#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  create_selfsigned_cert
#   DESCRIPTION:  Create a CA and a self signed certificate for $FQDN
#    PARAMETERS:
#       RETURNS:
#----------------------------------------------------------------------------------------------------------------------
create_selfsigned_cert() {
  throw_info "Creating self-signed certificate for $FQDN"
  mkdir -p /etc/rport/ssl/ca/export
  SSL_KEY_FILE=/etc/rport/ssl/${FQDN}_privkey.pem
  SSL_CERT_FILE=/etc/rport/ssl/${FQDN}_certificate.pem
  SSL_CSR_FILE=/etc/rport/ssl/${FQDN}.csr
  SSL_EXT_FILE=/etc/rport/ssl/${FQDN}.ext
  ################## Create a CA #############################################
  # Generate private key
  CA_NAME=${FQDN}
  CA_CERT=/etc/rport/ssl/ca/export/${CA_NAME}-ca-root-cert.crt
  CA_KEY=/etc/rport/ssl/${CA_NAME}-ca.key
  openssl genrsa -out "${CA_KEY}" 2048
  # Generate root certificate
  openssl req -x509 -new -nodes -key "${CA_KEY}" -sha256 -days 825 -out "${CA_CERT}" \
    -subj "/C=GB/ST=London/L=London/O=Global Security/OU=IT Department/CN=${CA_NAME}.local"

  if [ -e "${CA_CERT}" ]; then
    throw_debug "Certificate Authority created in ${CA_CERT}. Import this file into OS and/or browser."
    throw_info "Read https://kb.rport.io/ carefully."
  else
    throw_fatal "Creating Certificate Authority failed."
    false
  fi
  ln -sf "$CA_CERT" /etc/rport/ssl/ca/export/rport-ca.crt
  sleep 0.1

  ########################## Create a CA-signed cert  ##########################
  # Generate a private key
  openssl genrsa -out "${SSL_KEY_FILE}" 2048
  # Create a certificate-signing request
  openssl req -new -key "${SSL_KEY_FILE}" -out "${SSL_CSR_FILE}" \
    -subj "/C=GB/ST=London/L=London/O=Global Security/OU=IT Department/CN=${FQDN}"
  # Create a config file for the extensions
  cat >"${SSL_EXT_FILE}" <<-EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${FQDN}      # Be sure to include the domain name here because Common Name is not so commonly honoured by itself
DNS.2 = $(hostname)  # Be sure to include the domain name here because Common Name is not so commonly honoured by itself
IP.1 = $(local_ip || external_ip) # Optionally, add an IP address (if the connection which you have planned requires it)
EOF
  # Create the signed certificate
  openssl x509 -req -in "${SSL_CSR_FILE}" -CA "${CA_CERT}" -CAkey "${CA_KEY}" -CAcreateserial \
    -out "${SSL_CERT_FILE}" -days 825 -sha256 -extfile "${SSL_EXT_FILE}"
  echo ""
  throw_debug "SSL key and self-signed certificate created."
  chown rport:root "$SSL_KEY_FILE"
  chown rport:root "$SSL_CERT_FILE"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  create_letsencrypt_cert
#   DESCRIPTION:  Request a Let's encrypt certificate for $FQDN
#    PARAMETERS:
#       RETURNS:  exitcode 1|0
#----------------------------------------------------------------------------------------------------------------------
create_letsencrypt_cert() {
  for i in $(seq 3); do
    throw_debug "Trying to request a Let's encrypt certificate [try $i]"
    if certbot certonly -d "${FQDN}" -n --agree-tos --standalone --register-unsafely-without-email; then
      CERTS_READY=1
      break
    else
      CERTS_READY=0
      sleep 5
    fi
  done
  if [ $CERTS_READY -eq 0 ]; then
    echo "------------------------------------------------------------------------------"
    throw_error "Creating Let's encrypt certificates for your RPort server failed."
    return 1
  fi
  # Change group ownerships so rport can read the files
  CERT_ARCH_DIR=$(find /etc/letsencrypt/archive/ -type d -iname "${FQDN}*")
  CERT_LIVE_DIR=$(find /etc/letsencrypt/live/ -type d -iname "${FQDN}*")
  chgrp rport /etc/letsencrypt/archive/
  chmod g+rx /etc/letsencrypt/archive/
  chgrp rport /etc/letsencrypt/live/
  chmod g+rx /etc/letsencrypt/live/
  chgrp rport "${CERT_ARCH_DIR}"
  chmod g+rx "${CERT_ARCH_DIR}"
  chgrp rport "${CERT_ARCH_DIR}"/privkey1.pem
  chmod g+rx "${CERT_ARCH_DIR}"/privkey1.pem
  chgrp rport "${CERT_LIVE_DIR}"
  SSL_KEY_FILE="${CERT_LIVE_DIR}"/privkey.pem
  SSL_CERT_FILE="${CERT_LIVE_DIR}"/fullchain.pem
  HOOK_FILE=/etc/letsencrypt/renewal-hooks/deploy/restart-rportd
  echo '#!/bin/sh
test -e /usr/bin/logger && /usr/bin/logger -t certbot "Restarting rportd after certificate renewal"
/usr/bin/systemctl restart rportd' >$HOOK_FILE
  chmod 0700 $HOOK_FILE
  throw_info "Certificates have been created for your instance "
}

if [ "$API_PORT" -ne 443 ]; then
  throw_info "Skipping Let's encrypt because ACME does not support none default ports."
  create_selfsigned_cert
elif [ "$PUBLIC_FQDN" -ne 1 ]; then
  throw_info "Skipping Let's encrypt because ACME supports only publicly resolvable hostnames."
  create_selfsigned_cert
else
  if create_letsencrypt_cert; then
    true
  else
    throw_info "Falling back to self-signed certificates"
    create_selfsigned_cert
  fi
fi
