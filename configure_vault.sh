#!/bin/bash

export VAULT_ADDR="http://localhost:8200"
export VAULT_TOKEN="vault"

echo "    Initialising with 1 Key"
init_json=$(vault operator init -key-shares=1 -key-threshold=1 -format=json)
root_token=$(echo "$init_json" | jq -r .root_token)
unseal_key=$(echo "$init_json" | jq -r .unseal_keys_b64[0])

echo "    Unseal key: $unseal_key"
echo "    Root token: $root_token"

echo "    Unsealing Vault"
vault operator unseal "$unseal_key"

export VAULT_TOKEN="$root_token"

# create root ca
certs_dir="$ROOT_CA_DIR"
pem=$(cat $certs_dir/ca.crt $certs_dir/private.key)

echo "    Creating Root CA"
vault secrets enable -path=pki_root pki
vault secrets tune -max-lease-ttl=87600h pki_root
vault write pki_root/config/ca pem_bundle="$pem"

# create the intermediate
echo "    Creating Intermediate CA"
vault secrets enable pki
vault secrets tune -max-lease-ttl=43800h pki

csr=$(vault write pki/intermediate/generate/internal \
  -format=json common_name="$HOSTNAME Dev Intermdiate CA" \
  | jq -r .data.csr)

intermediate=$(vault write pki_root/root/sign-intermediate \
  -format=json csr="$csr" format=pem_bundle ttl=43800h \
  | jq -r .data.certificate)

chained=$(echo -e "$intermediate\n$(cat $certs_dir/ca.crt)")

vault write pki/intermediate/set-signed certificate="$chained"

echo "    Creating 'cert' role"
echo "    Allowed domains: localhost, $DOMAIN, dc1.consul"
vault write pki/roles/cert \
  allowed_domains=localhost,$DOMAIN,dc1.consul \
  allow_subdomains=true \
  max_ttl="24h"

echo "    Removing root CA"
vault secrets disable pki_root

echo "$root_token"
