#!/bin/bash

set -e

export VAULT_ADDR="http://$VAULT_HOSTNAME.$DOMAIN:8200"
echo "Using Vault Token: $VAULT_TOKEN"

config_dir="/etc/consul.d"
mkdir -p "$config_dir/ca"

response=$(vault write pki/issue/cert -format=json \
  common_name=$HOSTNAME.$DOMAIN \
  alt_names="server.dc1.consul")

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
    "bootstrap_expect": 3,
    "client_addr": "0.0.0.0",
    "data_dir": "/var/consul",
    "leave_on_terminate": true,
    "rejoin_after_leave": true,
    "retry_join": ["consul1.$DOMAIN", "consul2.$DOMAIN", "consul3.$DOMAIN"],
    "server": true,
    "ui": true,
    "encrypt": "oNMJiPZRlaP8RnQiQo9p8MMK5RSJ+dXA2u+GjFm1qx8=",
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
) | sudo tee $config_dir/consul.json

(
cat <<-EOF
[Unit]
Description=consul agent
Requires=network-online.target
After=network-online.target

[Service]
Restart=on-failure
ExecStart=/usr/bin/consul agent -config-file=$config_dir/consul.json -bind '{{ GetInterfaceIP "eth0" }}'
ExecReload=/bin/kill -HUP $MAINPID

[Install]
WantedBy=multi-user.target
EOF
) | sudo tee /etc/systemd/system/consul.service

sudo systemctl enable consul.service
sudo systemctl restart consul
