name: Test-%NAME
on: 
  push:
    branches:
      - master
jobs:
  Test-%NAME:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v2
      - name: initalize LXD
        run: |
          sudo snap install lxd --channel=latest/stable
          sudo chmod o+g '/var/snap/lxd/common/lxd/unix.socket'
          cat <<EOF | lxd init --preseed
          storage_pools:
          - name: default
            driver: dir
          networks:
          - name: lxdbr0
            type: bridge
            config:
              ipv4.address: auto
              ipv6.address: none
          profiles:
          - name: default
            devices:
              root:
                path: /
                pool: default
                type: disk
          EOF
          lxc profile device add default eth0 nic name=eth0 network=lxdbr0
        shell: bash
      - name: Create Container
        shell: bash
        run: bash .github/scripts/create-container.sh %NAME
      - name: Install RPortd
        shell: bash
        run: (lxc exec %NAME -- bash -s -- --no-2fa --fqdn rportd.localnet.local)< rportd-installer.sh
      - name: Run Test
        shell: bash
        run: (lxc exec %NAME -- bash)< .github/scripts/run-test.sh
      - name: Uninstall RPortd
        shell: bash
        run: (lxc exec %NAME -- bash -s -- -u)< rportd-installer.sh