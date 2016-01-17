# -*- mode: ruby -*-
# vi: set ft=ruby :

require "yaml"

# Load vagrant-puppet-django config
current_dir = File.dirname(File.expand_path(__FILE__))
config_file = YAML.load_file("#{current_dir}/config.yaml")

Vagrant.configure(2) do |config|
  config.vm.box = "ubuntu/wily32"

  config.vm.provider "virtualbox" do |vb|
    vb.memory = "1024"
  end

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  config.vm.network "forwarded_port", guest: 80, host: 8080

  # Sync current folder on host to your project folder on guest machine.
  #config.vm.synced_folder ".", "/home/#{config_file['user']}/virtualenvs/#{config_file['domain_name']}"
  config.vm.synced_folder "code", "/opt/code"
  # Path to the included files for Puppet.
  config.vm.synced_folder "manifests/files", config_file["inc_file_path"]

  config.vm.provision "puppet" do |puppet|
    puppet.manifests_path = "manifests"
    puppet.manifest_file = "site.pp"
    puppet.facter = {
      "inc_file_path" => config_file["inc_file_path"],
      "tz"            => config_file["tz"],
      "user"          => config_file["user"],
      "password"      => config_file["password"],
      "project"       => config_file["project"],
      "domain_name"   => config_file["domain_name"],
      "venv_name"     => config_file["venv_name"],
      "db_name"       => config_file["db_name"],
      "db_user"       => config_file["db_user"],
      "db_password"   => config_file["db_password"],
    }
  end
end
