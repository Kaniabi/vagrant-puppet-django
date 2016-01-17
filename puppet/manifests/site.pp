# This script we modified from
#   https://github.com/tianissimo/vagrant-puppet-django
#
# Everything noted with "EDIT:" means commented out from the original but kept
# for further reference.

Exec { path => '/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin' }

include timezone
include user
include apt
include nginx
include uwsgi
include mysql
#include python
include virtualenv
include pildeps
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

  # Prepare user's project directories
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

class nginx {
  $sock_dir = '/tmp/uwsgi' # Without a trailing slash

  package { 'nginx':
    ensure => latest,
    require => Class['apt']
  }

  service { 'nginx':
    ensure => running,
    enable => true,
    require => Package['nginx']
  }

  file { '/etc/nginx/sites-enabled/default':
    ensure => absent,
    require => Package['nginx']
  }

  file { 'sites-available config':
    path => "/etc/nginx/sites-available/${domain_name}",
    ensure => file,
    content => template("${manifests_path}/nginx/nginx.conf.erb"),
    require => Package['nginx']
  }

  file { "/etc/nginx/sites-enabled/${domain_name}":
    ensure => link,
    target => "/etc/nginx/sites-available/${domain_name}",
    require => File['sites-available config'],
    notify => Service['nginx']
  }
}

class uwsgi {
  $sock_dir = '/tmp/uwsgi' # Without a trailing slash
  $uwsgi_user = 'www-data'
  $uwsgi_group = 'www-data'

  package { 'uwsgi':
    ensure => latest,
    provider => pip,
    require => Class['python']
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

  # Prepare a directory for sock file
  file { [$sock_dir]:
    ensure => directory,
    owner => "${uwsgi_user}",
    group => "${uwsgi_user}",
    require => Package['uwsgi']
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
}

class mysql {
  $create_db_cmd = "CREATE DATABASE ${db_name} CHARACTER SET utf8;"
  $create_user_cmd = "CREATE USER '${db_user}'@localhost IDENTIFIED BY '${db_password}';"
  $grant_db_cmd = "GRANT ALL PRIVILEGES ON ${db_name}.* TO '${db_user}'@localhost;"

  package { 'mysql-server':
    ensure => latest,
    require => Class['apt']
  }

  package { 'libmysqlclient-dev':
    ensure => latest,
    require => Class['apt']
  }

  service { 'mysql':
    ensure => running,
    enable => true,
    require => Package['mysql-server']
  }

  exec { 'grant user db':
    command => "mysql -u root -e \"${create_db_cmd}${create_user_cmd}${grant_db_cmd}\"",
    unless => "mysqlshow -u${db_user} -p${db_password} ${db_name}",
    require => Service['mysql']
  }
}

class { 'python' :
  version    => 'system',
  pip        => 'present',
  dev        => 'present',
  virtualenv => 'present',
  gunicorn   => 'absent',
}

class virtualenv {

  python::virtualenv { "virtualenv":
    ensure       => present,
    version      => 'system',
    requirements => $requirements_path,
    #proxy        => 'http://proxy.domain.com:3128',
    systempkgs   => false,
    distribute   => false,
    venv_dir     => "${virtualenvs_path}/${project}",
    owner        => $user,
    timeout      => 0
    #require => Package['virtualenv']
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
