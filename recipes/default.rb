#
# Cookbook Name:: firewall
# Recipe:: default
#
# Copyright 2011, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

src_folder   = "ufw-#{node['firewall']['ufw']['version']}"
src_filename = "#{src_folder}.tar.gz"
src_filepath = "#{Chef::Config['file_cache_path']}/#{src_filename}"
extract_path = "#{Chef::Config['file_cache_path']}/#{src_folder}"
ufw_bin      = '/usr/sbin/ufw'

remote_file "#{src_filepath}" do
  source "#{node['firewall']['ufw']['url']}/#{src_filename}"
  checksum "#{node['firewall']['ufw']['checksum']}"
  owner 'root'
  group 'root'
  mode 00644
end

bash 'install_ufw' do
  cwd ::File.dirname("#{src_filepath}")
  code <<-EOH
    tar xf #{src_filename}
		cd #{extract_path}
		sudo python ./setup.py install
		sudo chmod -R g-w /etc/ufw /lib/ufw /etc/default/ufw /usr/sbin/ufw
  EOH
  not_if { ::File.exists?("#{ufw_bin}") }
end

cookbook_file "/etc/init/ufw.conf" do
  backup false
  owner 'root'
  group 'root'
  mode 00644
  source 'ufw.conf'
  action :create_if_missing
end
