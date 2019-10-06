# Vault & Consul TLS Bootstrap

This script (`run.sh`) runs through setting up a Vault instance with a Consul cluster for storage, using certificates issued by Vault itself.

It accompanies a blog post which goes into more details of [How to build a TLS enabled Consul Cluster with Vault](https://andydote.co.uk/2019/10/06/vault-consul-bootstrap/).

## Requirements

Host machine needs:

* [Vagrant](https://www.vagrantup.com/)
* [Consul](https://www.consul.io/)
* [Vault](https://www.vaultproject.io/)

Environments:

* Windows: Hyper-V and an administrative Bash shell
* Linux: vagrant-libvirt plugin or virtualbox


## Environment Variables

* `ROOT_CA_DIR` - Required. Set to where you keep your root certificate & key.  [See this blog post for how to create a local CA](https://andydote.co.uk/2019/08/25/vault-development-ca/)
* `HOST_BIND_ADDRESS` - Optional. The address Consul will listen on

## Running

If you are running on Windows with Hyper-V, and running from a bash based shell, you can just run the script:

```bash
export ROOT_CA_DIR="/keybase/private/<user>/dev-ca"
./run.sh
```

Otherwise, you will probably want to specify what domain your machines are running under (for example, on Linux I use libvirt with a `tecra.xyz` domain for the machines):

```bash
export ROOT_CA_DIR="/keybase/private/<user>/dev-ca"
./run.sh "tecra.xyz"
```

The script will also attempt to find an IP address on your machine that the Vagrant machines can use to talk to the instance of Vault we will run, on Windows it looks for the default Hyper-V switch (`vEthernet (Default Switch)`) and on Linux uses `ip -4 route get 1`.

You can override this with the `HOST_BIND_ADDRESS` environment variable:

```bash
export ROOT_CA_DIR="/keybase/private/<user>/dev-ca"
export HOST_BIND_ADDRESS="172.72.0.58"
./run.sh "tecra.xyz"
```

