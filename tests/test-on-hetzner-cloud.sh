#!/usr/local/bin/bash
#
# Script for semi-automated test if the rportd-installer.sh on a public cloud VM
# Requires hcloud command line tool https://github.com/hetznercloud/cli
#
set -e
cd "$(dirname $0)"

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  init
#   DESCRIPTION:  Do what is needed to get started
#    PARAMETERS:  ?
#       RETURNS:
#----------------------------------------------------------------------------------------------------------------------
init() {
  echo " Initializing"
  (cd ..; ./create_installer.sh)
  # Source your personal settings
  . .env
  # Generate a name for the VM
  curl 'https://randomuser.me/api/?inc=name&noinfo&nat=gb,us' -fs -o /tmp/.name
  VM_PREFIX=$(jq -r .results[0].name.first </tmp/.name)-$(jq -r .results[0].name.last </tmp/.name)
  VM_PREFIX=$(echo "${VM_PREFIX}" | tr '[:upper:]' '[:lower:]')
  rm -f /tmp/.name
  VM_NAME=${VM_PREFIX}
  export FQDN=$FQDN
  export VM_NAME=$VM_NAME
  export GODADDY_TLD=$GODADDY_TLD
}

create_vm() {
  # Set the OS Image
  if [ -z "$OS_IMAGE" ]; then
    OS_IMAGE=debian-11
  else
    if hcloud image list | grep -q $OS_IMAGE; then
      true
    else
      echo "Image $OS_IMAGE does not exist. Exit"
      false
    fi
  fi
  echo "🐧 Using Image ${OS_IMAGE}"

  # Create the VM on a random datacenter
  LOCATION=$(jot -r 1 1 3)
  loc[1]='Falkenstein eu-central'
  loc[2]='Nuremberg eu-central'
  loc[3]='Helsinki eu-central'
  loc[4]='Ashburn us-east'
  echo "🌎 VM will be created in ${loc[$LOCATION]}"
  echo "🚴 Creating VM now ... "
  hcloud server create --type 1 --name "${VM_NAME}" --location "$LOCATION" --image ${OS_IMAGE} --ssh-key "${SSH_KEY}" >"$LOG_FILE"
  sleep 5
  IP=$(grep "^IPv4" "$LOG_FILE" | awk '{print $2}')
  echo "🚚 VM Created with IP address $IP"

  for i in $(seq 60); do
    ncat -w1 -z "${IP}" 22 && break
    sleep 1
    echo "$i" >/dev/null
  done
  export VM_ID=$VM_ID
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  create_random_fqdn
#   DESCRIPTION:  n.a.
#    PARAMETERS:  ?
#       RETURNS:
#----------------------------------------------------------------------------------------------------------------------
create_random_fqdn() {
  if [ -n "${GODADDY_TLD}" ]; then
    FQDN=${VM_NAME}.${GODADDY_TLD}
    echo "🏠 Creating DNS record ${FQDN} = ${IP} using daddy cli"
    daddy add -d "${GODADDY_TLD}" -t A -n "${VM_NAME}" -v "$IP"
    INSTALL_APPEND=$INSTALL_APPEND" --fqdn ${FQDN}"
    echo "FQDN: ${FQDN}" >>"$LOG_FILE"
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  execute_installer
#   DESCRIPTION:  Execute the installer on the remote machine
#    PARAMETERS:  ?
#       RETURNS:
#----------------------------------------------------------------------------------------------------------------------
execute_installer() {
  echo "🖥️  executing 'bash rportd-installer.sh ${INSTALL_APPEND}' remotely now."
  test -e remote-out.log && rm -f remote-out.log
  SSH_OPTS="-o StrictHostKeyChecking=no -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null -l root"
  ssh ${SSH_OPTS} "${IP}" "bash -s -- ${INSTALL_APPEND}" <../rportd-installer.sh | tee remote-out.log
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  do_tests
#   DESCRIPTION:  Do some basic tests
#    PARAMETERS:  ?
#       RETURNS:
#----------------------------------------------------------------------------------------------------------------------
do_tests() {
  ADMIN_PASSWORD=$(grep "Password =" remote-out.log | cut -d'=' -f2 | tr -d ' ')
  curl -fIv https://"${FQDN}"
  curl -fs https://"${FQDN}"/api/v1/login -u admin:"${ADMIN_PASSWORD}"
  echo ""
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  delete_vm
#   DESCRIPTION:  Delete the VM created before. Takes all data from the env
#    PARAMETERS:  ?
#       RETURNS:
#----------------------------------------------------------------------------------------------------------------------
delete_vm() {
  # Delete the VM
  VM_ID=$(grep "Server .* created" $LOG_FILE | awk '{print $2}')
  echo "💣 Deleting VM ${VM_NAME} [${VM_ID}]"
  hcloud server delete "$VM_ID"

  # Delete the FQDN
  FQDN=$(grep "^FQDN" "$LOG_FILE" | awk '{print $2}')
  if echo "$FDQN" | grep -q "${GODADDY_TLD}"; then
    echo "Deleting FQDN ${FQDN}"
    TLD=$(echo "$FQDN"|cut -d'.' -f2-3)
    NAME=$(echo "$FQDN"|cut -d'.' -f1)
    daddy remove -d "${TLD}" -t A -n "${NAME}" -f
    daddy show -d "${TLD}"
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  help
#   DESCRIPTION:  print a help message
#    PARAMETERS:  ?
#       RETURNS:
#----------------------------------------------------------------------------------------------------------------------
help() {
  echo "
Usage $0 [OPTION(s)]

-h,--help show this help message
-f,--fqdn use FQDN for the new rport server instead of generating a random one.
-r,--random-fqdn generate a random FQDN locally before executing the installer.
-i,--installer-args append string(s) to the rportd-installer.sh
-d,--delete-vm
"
}

# parse options
TEMP=$(getopt \
  -o dhri: \
  --long help,random-fqdn,delete-vm,installer-args: \
  -- "$@")
eval set -- "$TEMP"
INSTALL_APPEND=""
RANDOM_FQDN=0
LOG_FILE="cloud-test.log"

# extract options and their arguments into variables.
while true; do
  case "$1" in
  -h | --help)
    help
    exit 0
    ;;
  -r | --random-fqdn)
    RANDOM_FQDN=1
    shift 1
    ;;
  -i | --installer-args)
    INSTALL_APPEND="$2"
    shift 2
    ;;
  -d | --delete-vm)
    delete_vm
    exit 0
    ;;
  --)
    shift
    break
    ;;
  *)
    echo "Internal error!"
    help
    exit 1
    ;;
  esac
done

init
create_vm
if [ $RANDOM_FQDN -eq 1 ]; then create_random_fqdn; fi
execute_installer
