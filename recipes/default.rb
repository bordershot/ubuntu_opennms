#
# Cookbook Name:: ubuntu_opennms
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

apt_repository 'opennms' do
  uri          'http://debian.opennms.org'
  distribution 'stable'
  components   ['main']
  key          'http://debian.opennms.org/OPENNMS-GPG-KEY'
end

apt_repository 'oracle repo' do
  uri          'http://ppa.launchpad.net/webupd8team/java/ubuntu'
  distribution 'xenial'
  components   ['main']
  key          'EEA14886'
end

bash 'accept java license' do
  code <<-EOH
  locale-gen en_US.UTF-8
  update-locale LANG=en_US.UTF-8
  echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections
  echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections
  export SKIP_IPLIKE_INSTALL=1
  apt-get -q -y install oracle-java8-installer
  apt-get -q -y install opennms
  EOH
end

#apt_package 'opennms'

service 'postgresql' do
  action :start
end

bash 'postgres setup' do
  user 'postgres'
  code <<-EOH
  psql -c "CREATE USER #{node['ubuntu_opennms']['opennms_user']} WITH PASSWORD '#{node['ubuntu_opennms']['opennms_pass']}'" 
  psql -c "CREATE DATABASE opennms OWNER #{node['ubuntu_opennms']['opennms_user']} ENCODING 'utf8'"
  psql -c "ALTER USER #{node['ubuntu_opennms']['postgres_user']} WITH PASSWORD '#{node['ubuntu_opennms']['postgres_pass']}'"
  EOH
end

template '/usr/share/opennms/etc/opennms-datasources.xml' do
  source 'opennms-datasources.xml.erb'
end

replace_line '/etc/postgresql/9.5/main/pg_hba.conf' do
  replace 'host    all             all             127.0.0.1/32            md5'
  with 'host    all             all             127.0.0.1/32            trust'
end

replace_line '/etc/postgresql/9.5/main/pg_hba.conf' do
  replace 'host    all             all             ::1/128                 md5'
  with 'host    all             all             ::1/128                 trust'
end

service 'postgresql' do
  action :restart
end

bash 'initialize opennms' do
  cwd '/usr/share/opennms/bin'
  code <<-EOH
  ./runjava -s
  ./install -dis
  /usr/sbin/install_iplike.sh
  ./install -dis
  EOH
end

service 'opennms' do
  action [ :start, :enable ]
end
