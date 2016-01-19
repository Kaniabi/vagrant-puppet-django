# This script we modified from
#   https://github.com/tianissimo/vagrant-puppet-django
#
# Everything noted with "EDIT:" means commented out from the original but kept
# for further reference.

Exec { path => '/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin' }

include timezone
include user
include apt
include python_
include nodejs_
include nginx_
include uwsgi_
include mysql_
include pildeps
include virtualenv
include software

class timezone {
  package { "tzdata":
    ensure => latest,
    require => Class['apt']
  }

  file { "/etc/localtime":
    require => Package["tzdata"],
    source => "file:///usr/share/zoneinfo/${tz}",
  }
}

class user {
  exec { 'add user':
    command => "sudo useradd -m -G sudo -s /bin/bash ${user}",
    unless => "id -u ${user}"
  }

  exec { 'set password':
    command => "echo \"${user}:${password}\" | sudo chpasswd",
    require => Exec['add user']
  }

  file {
    [
      "${virtualenvs_path}",
      "${logs_path}",
      "${public_html_path}",
      "${public_html_path}/${domain_name}",
      "${public_html_path}/${domain_name}/static"
    ]:
    ensure => directory,
    owner => "${user}",
    group => "${user}",
    require => Exec['add user'],
    before => File['media dir']
  }

  file { 'media dir':
    path => "${public_html_path}/${domain_name}/media",
    ensure => directory,
    owner => "${user}",
    group => 'www-data',
    mode => 0775,
    require => Exec['add user']
  }
}

class apt {
  exec { 'apt-get update':
    # Ignoring error 100 related to 404 mirror searching (I guess).
    returns  => [0, 100],
    timeout  => 0,
    schedule => "daily",
  }

  package { 'python-software-properties':
  ensure => latest,
  require => Exec['apt-get update']
  }
  exec { 'add-apt-repository ppa:nginx/stable':
    require => Package['python-software-properties'],
    before => Exec['last ppa']
  }

  exec { 'last ppa':
    command => 'add-apt-repository ppa:git-core/ppa',
    require => Package['python-software-properties']
  }

  exec { 'apt-get update again':
    command => 'apt-get update',
    returns => [0, 100],  # See "apt-get update"
    timeout => 0,
    require => Exec['last ppa']
  }
}

class python_ {
  class { 'python':
    version    => 'system',
    pip        => 'present',
    dev        => 'present',
    virtualenv => 'present',
    gunicorn   => 'absent',
  }
}

class nodejs_ {
  package { 'nodejs': require => Exec['apt-get update'] }
  package { 'npm': require => Package['nodejs'] }
  package { 'compress': provider => 'npm', require => Package['npm'] }
  package { 'sass': provider => 'npm', require => Package['npm'] }
}

class ruby_ {
  # I believe that ruby is already installed in ubuntu wily package because of puppet.
  package { 'bower': provider => 'gem', require => Exec['apt-get update'] }
}

class nginx_ {
  class { 'nginx':
    require => Class['apt']
  }

  file { 'sites-available config':
    path => "/etc/nginx/sites-available/${project}.conf",
    ensure => file,
    content => template("${manifests_path}/nginx/nginx.conf.erb"),
    require => Class['nginx']
  }

  file { "sites-enabled config":
    path => "/etc/nginx/sites-enabled/${project}.conf",
    ensure => link,
    target => "/etc/nginx/sites-available/${project}.conf",
    require => File['sites-available config'],
  }
}

class uwsgi_ {
  package { 'uwsgi':
    ensure => latest,
    provider => pip,
    require => Class['python_']
  }

  service { 'uwsgi':
    ensure => running,
    enable => true,
    require => File['apps-enabled config']
  }

  # Prepare directories
  file { ['/var/log/uwsgi', '/etc/uwsgi', '/etc/uwsgi/apps-available', '/etc/uwsgi/apps-enabled']:
    ensure => directory,
    require => Package['uwsgi'],
    before => File['apps-available config']
  }

  file { 'systemd service':
    path => '/etc/systemd/system/uwsgi.service',
    ensure => file,
    content => template("${manifests_path}/uwsgi/uwsgi.service.erb"),
    require => Package['uwsgi']
  }

  # Vassals ini file
  file { 'apps-available config':
    path => "/etc/uwsgi/apps-available/${project}.ini",
    ensure => file,
    content => template("${manifests_path}/uwsgi/uwsgi.ini.erb")
  }

  file { 'apps-enabled config':
    path => "/etc/uwsgi/apps-enabled/${project}.ini",
    ensure => link,
    target => "/etc/uwsgi/apps-available/${project}.ini",
    require => File['apps-available config']
  }

  # # TRYING with uwsgi module with no success. No suport for systemd...
  #
  # # It seems that uwsgi module doesn't create this (essential) directory.
  # file { '/etc/uwsgi': ensure => directory }
  #
  # class { 'uwsgi':
  #   package_ensure => 'latest',
  #   service_ensure  => 'running',
  #   service_provider => 'redhat',
  #   python_pip => 'pip',  # Avoid conflict (redeclaration) with python module.
  #   require => File['/etc/uwsgi']
  # }
}

class mysql_ {

  $override_options = {}

  class { '::mysql::server':
    root_password           => 'chucknorris',
    remove_default_accounts => true,
    override_options        => $override_options
  }

  class { '::mysql::client':
  }

  class { '::mysql::bindings':
    client_dev => 'true',  # Python's mysql related packages need this
    client_dev_package_ensure => 'present'
  }

  mysql::db { "${db_name}":
    user => "${db_user}",
    password => "${db_password}",
    host => 'localhost',
    grant => ['ALL PRIVILEGES']
  }
}

class virtualenv {
  python::virtualenv { "virtualenv":
    ensure       => present,
    version      => 'system',
    requirements => $requirements_path,
    systempkgs   => false,
    distribute   => false,
    venv_dir     => "${virtualenvs_path}/${project}",
    owner        => $user,
    timeout      => 0
  }
}

class pildeps {
  package { ['python-imaging', 'libjpeg-dev', 'libfreetype6-dev']:
    ensure => latest,
    require => Class['apt'],
    before => Exec['pil png', 'pil jpg', 'pil freetype']
  }

  exec { 'pil png':
    command => 'sudo ln -s /usr/lib/`uname -i`-linux-gnu/libz.so /usr/lib/',
    unless => 'test -L /usr/lib/libz.so'
  }

  exec { 'pil jpg':
    command => 'sudo ln -s /usr/lib/`uname -i`-linux-gnu/libjpeg.so /usr/lib/',
    unless => 'test -L /usr/lib/libjpeg.so'
  }

  exec { 'pil freetype':
    command => 'sudo ln -s /usr/lib/`uname -i`-linux-gnu/libfreetype.so /usr/lib/',
    unless => 'test -L /usr/lib/libfreetype.so'
  }
}

class software {
  package { 'git':
    ensure => latest,
    require => Class['apt']
  }

  package { 'vim':
    ensure => latest,
    require => Class['apt']
  }
}

# Schedules to avoid executing time/resource consuming tasks on every puppet run.
# This was designed initially to execute "apt-get update" only once a day.
schedule { "daily":
  period => daily,
  repeat => 1,
}
