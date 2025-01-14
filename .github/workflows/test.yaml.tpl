name: Test-%NAME
on: 
  push:
    branches:
      - main
jobs:
  Test-%NAME:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v2
      - name: Install Dependencies
        shell: bash
        run: |
          set -e
          cat /etc/os-release
          sudo apt-get update >/dev/null
          sudo DEBIAN_FRONTEND=noninteractive apt-get install -y curl jq ncat
          curl -LOs "https://github.com/koalaman/shellcheck/releases/download/v0.8.0/shellcheck-v0.8.0.linux.x86_64.tar.xz"
          tar xf shellcheck-v0.8.0.linux.x86_64.tar.xz shellcheck-v0.8.0/shellcheck
          sudo mv shellcheck-v0.8.0/shellcheck /usr/local/bin/
          shellcheck -V
      - name: Initialize LXD
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
      - name: Create scripts from snippets
        shell: bash
        run: |
            bash create_installer.sh
            bash create_update.sh
      - name: Install RPortd
        shell: bash
        run: (lxc exec %NAME -- bash -s -- --no-2fa --fqdn rportd.localnet.local)< rportd-installer.sh
      - name: Run Test
        shell: bash
        run: (lxc exec %NAME -- bash)< .github/scripts/run-test.sh
      - name: Uninstall RPortd
        shell: bash
        run: (lxc exec %NAME -- bash -s -- -u)< rportd-installer.sh