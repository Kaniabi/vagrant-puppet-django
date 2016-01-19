# -*- mode: ruby -*-
# vi: set ft=ruby :

require "yaml"

# Load vagrant-puppet-django config
current_dir = File.dirname(File.expand_path(__FILE__))
config_file = YAML.load_file("#{current_dir}/config.yaml")

working_path="/home/#{config_file['user']}"

manifests_path="#{working_path}/manifests"
code_path="#{working_path}/code"
logs_path="#{working_path}/logs"
virtualenvs_path="#{working_path}/virtualenvs"
requirements_path= "#{code_path}/#{config_file['project']}/#{config_file['requirements_path']}"

Vagrant.configure(2) do |config|
  config.vm.box = "ubuntu/wily32"

  config.vm.provider "virtualbox" do |vb|
    vb.memory = "1024"
  end

  config.vm.network "forwarded_port", guest: 80, host: 8080

  config.vm.synced_folder "puppet/manifests/files", "#{manifests_path}"
  config.vm.synced_folder "code",                   "#{code_path}"

  config.vm.provision "puppet" do |puppet|
    puppet.manifests_path = "puppet/manifests"
    puppet.module_path = "puppet/modules"
    puppet.manifest_file = "site.pp"
    puppet.hiera_config_path = "puppet/hiera.yaml"
    puppet.facter = {
      "tz"             => config_file["tz"],
      "user"           => config_file["user"],
      "password"       => config_file["password"],

      "manifests_path"    => "#{manifests_path}",
      "code_path"         => "#{code_path}",
      "logs_path"         => "#{logs_path}",
      "virtualenvs_path"  => "#{working_path}/virtualenvs",
      "public_html_path"  => "#{working_path}/public_html",
      "requirements_path" => "#{requirements_path}",

      "project"        => config_file["project"],
      "domain_name"    => config_file["domain_name"],
      "db_name"        => config_file["db_name"],
      "db_user"        => config_file["db_user"],
      "db_password"    => config_file["db_password"],
    }
  end
end
