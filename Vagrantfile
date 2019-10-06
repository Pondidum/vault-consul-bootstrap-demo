Vagrant.configure(2) do |config|
  config.vm.box = "local/hashibox"

  config.vm.provision "consul",
    type: "shell",
    path: "./provision.sh",
    env: {
      "VAULT_TOKEN" => ENV["CONSUL_VAULT_TOKEN"],
      "DOMAIN" => ENV["DOMAIN"],
      "VAULT_HOSTNAME" => ENV["HOSTNAME"]
    }

  config.vm.provider "hyperv" do |h, override|
    h.memory = "1024"
    h.linked_clone = true
    override.vm.network "public_network", bridge: "Default Switch"
    override.vm.synced_folder ".", "/vagrant", smb_username: ENV['VAGRANT_SMB_USER'], smb_password: ENV['VAGRANT_SMB_PASS']
  end

  config.vm.define "c1" do |c1|
    c1.vm.hostname = "consul1"
  end

  config.vm.define "c2" do |c2|
    c2.vm.hostname = "consul2"
  end

  config.vm.define "c3" do |c3|
    c3.vm.hostname = "consul3"
  end
end