#!/usr/bin/env bash
set -e

CONTAINER="$1"

#Delete container, if exists
if lxc info "$CONTAINER" >/dev/null 2>&1; then
  echo "💣 Deleting container $CONTAINER"
  lxc delete "$CONTAINER" --force
fi

# Command(s) executed inside container directly after creation
POST_EXEC=("cat /etc/os-release")
echo "🐇 Launching container now. Wait ... "
case $CONTAINER in
focal)
  lxc launch ubuntu:20.04 container -q
  POST_EXEC+=("apt-get -y update;apt-get -y install jq")
  ;;
jammy)
  lxc launch ubuntu:22.04 container -q
  POST_EXEC+=("apt-get -y update;apt-get -y install jq")
  ;;
bullseye)
  lxc launch images:debian/11 container -q
  POST_EXEC+=("apt-get -y update;apt-get -y install curl jq")
  ;;
rocky)
  lxc launch images:rockylinux/8 container -q
  POST_EXEC+=("dnf -y install epel-release jq")
  ;;
*)
  echo "Unsupported OS"
  exit 1
  ;;
esac
echo "🚚 Container launched"
for i in $(seq 60); do
  echo "🚴‍♂️ waiting for container to come up $i"
  if lxc ls | grep -q "container.*RUNNING.*10\."; then
    echo "🎉 container running"
    break
  fi
  sleep 2
done
echo "🐸 Executing '\$POST_EXEC' inside container"
printf "%s\n" "${POST_EXEC[@]}" | lxc exec container -- bash
