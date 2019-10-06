#!/bin/bash

set -e

export DOMAIN=${1:-"mshome.net"}

if [ -z "$HOST_BIND_ADDRESS" ]; then
  if [ -x "$(command -v netsh)" ]; then
    export HOST_BIND_ADDRESS=$(netsh interface ip show addresses "vEthernet (Default Switch)" | sed -n 's/.*IP Address:\s*//p')
  else
    export HOST_BIND_ADDRESS=$(ip -4 route get 1 | awk '{print $(NF-2);exit}')
  fi
fi

echo "==> Running Bootstrap Script"
echo "    Host is $HOSTNAME ($HOST_BIND_ADDRESS)"
echo "    Domain is $DOMAIN"
echo "    Using certificates from $ROOT_CA_DIR"

config_dir=".config/vault"

rm -rf "$config_dir"
mkdir -p "$config_dir"

echo "==> Configuring Temporary Vault CA"

echo '
storage "inmem" {}
listener "tcp" {
  address = "0.0.0.0:8200"
  tls_disable = 1
}' > "$config_dir/temp_vault.hcl"

vault server -config="$config_dir/temp_vault.hcl" > /dev/null &
echo "$!" > vault.pid

echo "    PID is $(cat vault.pid)"

echo "    Configuring Vault"
export VAULT_TOKEN=$(./configure_vault.sh | tail -n 1)

export CONSUL_VAULT_TOKEN=$(vault write -field=token -force auth/token/create)
echo "    Created Access Token $CONSUL_VAULT_TOKEN for consul nodes"
echo "    Done"

echo "==> Starting Consul Cluster"
vagrant up

# Connect a local consul instance to the cluster
sleep 10

./local_consul.sh

# Wait for Consul to be happy
sleep 10

# Stop temp Vault
kill $(cat vault.pid)
rm vault.pid

echo "==> Done."


# Start Persistent Vault instance
echo "==> Configuring Persistent Vault CA"

echo '
storage "consul" {
  address = "'"$HOSTNAME"'.'"$DOMAIN"':8501"
  scheme = "https"
}
listener "tcp" {
  address = "0.0.0.0:8200"
  tls_disable = 1
}' > "$config_dir/persistent_vault.hcl"

vault server -config="$config_dir/persistent_vault.hcl" > /dev/null &
echo "$!" > vault.pid
echo "    PID is $(cat vault.pid)"

sleep 10

echo "    Configuring Vault"
export VAULT_TOKEN=$(./configure_vault.sh | tail -n 1)

sleep 10

export CONSUL_VAULT_TOKEN=$(vault write -field=token -force auth/token/create)
echo "    Created Access Token $CONSUL_VAULT_TOKEN for consul nodes"
echo "    Done"


echo "==> Reprovisioning Consul 1"
# Kill nodes and replace with Persistent Vault provisioned versions
vagrant provision c1 --provision-with consul
sleep 5

echo "==> Reprovisioning Consul 2"
vagrant provision c2 --provision-with consul
sleep 5

echo "==> Reprovisioning Consul3"
vagrant provision c3 --provision-with consul

echo "==> Complete"
echo "    to clean up, run the following:"
echo '    kill $(cat vault.pid)'
echo '    kill $(cat consul.pid)'
