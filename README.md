A script to install and configure your RPort server in no time.

> 📣 This repository holds the sources of https://get.rport.io.

## Why an installer script?
We believe modern software must provide maximum user-friendliness. 
Installing an RPort server should not take longer than 5 minutes.

Discovering the awesome features of RPort should be fun. Therefore, we don't want to annoy you with long documentation.

🏋 The installer script does all the sisyphean task to set up the server properly and securely according to the standards of your Linux distribution.

### Supported environments
The script installs the RPort server on cloud VMs with a public IP address and on any server inside a local network behind NAT as well. 
If you are behind NAT, pay attention to used ports and the FQDN. [📖 Read more](https://kb.rport.io/install-the-rport-server/install-on-premises)

### Supported operating systems
While the RPort server itself is a statically compiled binary that runs ony almost any Linux or Windows, the installer script has some dependencies.

Currently, supported:

Distribution | Version | supported Archs                |Guacd support¹
-------------|---------|-----------------------------|------------------
Ubuntu Linux |20.04 (focal)| `x86_64` `aarch64`      | yes
Debian | 11 (bullseye) | `x86_64` `aarch64` `armv7l` | yes
Debian |10 (buster) | `x86_64` `aarch64` `armv7l`    | yes
RHEL²   | 8          | `x86_64`                      | no
*¹) For RDP on the browser, rportd depends on a guacamole proxy, just the tiny proxy binary installed via [Debian packages](https://bitbucket.org/cloudradar/rport-guacamole/src/main/). The installer handles it hassle-free.*
<br>*²) Includes all derivates like CentOS, Alma, and Rocky Linux.*

> 🧏 If you have the free choice, **we recommend Debian 11**. It's lean, and it has everything on board you need for a secure RPort server.

## Install an RPort server

⛔ The installer has many options, read the [full installation documentation](https://kb.rport.io/install-the-rport-server/install-on-premises) before you start the installation.

Then download the script and execute it.
```shell
curl -JO https://get.rport.io
sudo bash rportd-installer.sh -h
sudo bash rportd-installer.sh <YOUR-OPTIONS>
```

## Update an RPort server
We also provide a script for an easy update to the latest stable version.

Just download and execute.
```shell
curl -JO https://get.rport.io/update
sudo bash rportd-update.sh -h
sudo bash rportd-update.sh <YOUR-OPTIONS>
```