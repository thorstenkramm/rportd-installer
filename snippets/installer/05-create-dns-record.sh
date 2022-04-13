#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  wait_for_dns_ready
#   DESCRIPTION:  check the DNS in a loop until the new records becomes available.
#    PARAMETERS:  ?
#       RETURNS:
#----------------------------------------------------------------------------------------------------------------------
wait_for_dns_ready() {
  throw_info "Waiting for DNS to become ready ... be patient "
  echo -n " "
  for i in $(seq 15); do
    echo -n ". "
    sleep 1
  done
  for i in $(seq 30); do
    if fqdn_is_public "${FQDN}"; then
      throw_info "DNS entry has become available. "
      DNS_READY=1
      break
    else
      DNS_READY=0
      echo -n ". "
      sleep 1
    fi
  done
  if [ $DNS_READY -eq 0 ]; then
    throw_error "Your hostname $FQDN has not become available on the DNS."
    throw_hint "Go to https://rport.io/en/contact and ask for help."
    throw_fatal "Creating an FQDN for your RPort server failed. "
  fi
  throw_info "Waiting for DNS records being propagated ... be patient"
  echo -n " "
  for i in $(seq 10); do
    echo -n ". "
    sleep 1
  done
  echo ""
}

if [ -z "$FQDN" ]; then
  # Create a random DNS record if no FQDN is specified using the free dns service of RPort
  FQDN=$(curl -Ss https://freedns.rport.io -F create=random)
  DNS_CREATED=1
  PUBLIC_FQDN=1
  throw_info "Creating random FQDN on Freedns *.users.rport.io."
  wait_for_dns_ready
elif [[ $FQDN =~ (.*)\.users\.rport\.io$ ]]; then
  # Register a custom DNS record if no FQDN is specified using the free dns service of RPort
  # Requires an authorization token
  FQDN=$(curl -Ss https://freedns.rport.io -F create="${BASH_REMATCH[1]}" -F token="$DNSTOKEN")
  DNS_CREATED=1
  throw_info "Creating custom FQDN ${BASH_REMATCH[1]}.users.rport.io."
  wait_for_dns_ready
fi

if [ $DNS_CREATED -eq 1 ] && echo "$FQDN" | grep -i error; then
  throw_fatal "Creating DNS record failed"
  false
fi

throw_info "Name of your RPort server: $FQDN You can change it later."
