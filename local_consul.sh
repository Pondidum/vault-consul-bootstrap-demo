#!/bin/sh

echo "==> Creating local Consul server"

export VAULT_TOKEN="$CONSUL_VAULT_TOKEN"

config_dir=".config/consul"

echo "    Writing configuration to $config_dir"

rm -rf "$config_dir"
mkdir -p "$config_dir"

echo "    Fetching certificate from Vault"
response=$(vault write pki/issue/cert -format=json common_name=$HOSTNAME.$DOMAIN)
mkdir -p "$config_dir/ca"

for (( i=0; i<$(echo "$response" | jq '.data.ca_chain | length'); i++ )); do
  cert=$(echo "$response" | jq -r ".data.ca_chain[$i]")
  name=$(echo "$cert" | openssl x509 -noout -subject -nameopt multiline | sed -n 's/ *commonName *= //p' | sed 's/\s//g')

  echo "$cert" > "$config_dir/ca/$name.pem"
done

echo "$response" | jq -r .data.private_key > $config_dir/consul.key
echo "$response" | jq -r .data.certificate > $config_dir/consul.crt
echo "$response" | jq -r .data.issuing_ca >> $config_dir/consul.crt


(
cat <<-EOF
{
  "data_dir": "$config_dir/data",
  "encrypt": "oNMJiPZRlaP8RnQiQo9p8MMK5RSJ+dXA2u+GjFm1qx8=",
  "retry_join": ["consul1.$DOMAIN", "consul2.$DOMAIN", "consul3.$DOMAIN"],
  "verify_incoming_rpc": true,
  "verify_incoming_https": false,
  "verify_outgoing": true,
  "verify_server_hostname": true,
  "ca_path": "$config_dir/ca/",
  "cert_file": "$config_dir/consul.crt",
  "key_file": "$config_dir/consul.key",
  "ports": {
    "http": -1,
    "https": 8501
  }
}
EOF
) | tee "$config_dir/consul.json"

echo "    Starting agent bound to $HOST_BIND_ADDRESS"
consul agent -config-file="$config_dir/consul.json" -bind "$HOST_BIND_ADDRESS" -client "0.0.0.0" > /dev/null &
echo "$!" > consul.pid

echo "    PID is $(cat consul.pid)"
echo "    Done"