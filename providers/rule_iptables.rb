#
# Author:: Nick Henry (<nickh@standingcloud.com>)
# Cookbook Name:: firewall
# Provider:: rule_ufw
#
# Copyright 2013, Standing Cloud
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

include Chef::Mixin::ShellOut

action :allow do
  apply_rule('allow')
end

action :deny do
  apply_rule('deny')
end

action :reject do
  apply_rule('reject')
end

if @new_resource.direction ~= /^:in$/
  _direction = 'INPUT'
else if @new_resource.direction ~= /^:out$/
  _direction = 'OUTPUT'
else
  Chef::Log.warn("Unrecognized firewall direction: #{@new_resource.direction}.  Assuming ':in'...")
  _direction = 'INPUT'
end

private
# ufw allow from 192.168.0.4 to any port 22
# ufw deny proto tcp from 10.0.0.0/8 to 192.168.0.1 port 25
# ufw insert 1 allow proto tcp from 0.0.0.0/0 to 192.168.0.1 port 25
def apply_rule(type=nil)
  unless rule_exists?
    iptables_command = "iptables "
    if @new_resource.position
      iptables_command << "--insert #{@new_resource.position} "
    else
      iptables_command << "--append "
    end
    iptables_command << "#{@new_resource.direction} " if @new_resource.direction
    iptables_command << "#{type} "
    if @new_resource.interface
      if @new_resource.direction
        iptables_command << "on #{@new_resource.interface} "
      else
        iptables_command << "in on #{@new_resource.interface} "
      end
    end
    iptables_command << logging
    iptables_command << "proto #{@new_resource.protocol} " if @new_resource.protocol
    if @new_resource.source
      iptables_command << "from #{@new_resource.source} "
    else
      iptables_command << "from any "
    end
    iptables_command << "port #{@new_resource.dest_port} " if @new_resource.dest_port
    if @new_resource.destination
      iptables_command << "to #{@new_resource.destination} "
    else
      iptables_command << "to any "
    end
    if @new_resource.port
      iptables_command << "port #{@new_resource.port} "
    elsif @new_resource.ports
      iptables_command << "port #{@new_resource.ports.join(',')} "
    elsif @new_resource.port_range
      iptables_command << "port #{@new_resource.port_range.first}:#{@new_resource.port_range.last} "
    end

    Chef::Log.debug("ufw: #{iptables_command}")
    shell_out!(iptables_command)

    Chef::Log.info("#{@new_resource} #{type} rule added")
    shell_out!("ufw status verbose") # purely for the Chef::Log.debug output
    new_resource.updated_by_last_action(true)
  else
    Chef::Log.debug("#{@new_resource} #{type} rule exists..skipping.")
  end
end

def logging
  case @new_resource.logging
  when :connections
    "log "
  when :packets
    "log-all "
  else
    ""
  end
end

def port_and_proto
  (@new_resource.protocol) ? "#{@new_resource.port}/#{@new_resource.protocol}" : @new_resource.port
end

# TODO currently only works when firewall is enabled
def rule_exists?
  # To                         Action      From
  # --                         ------      ----
  # 22                         ALLOW       Anywhere
  # 192.168.0.1 25/tcp         DENY        10.0.0.0/8
  shell_out!("service iptables status").stdout =~ /^(#{@new_resource.destination}\s)?#{port_and_proto}\s.*(#{@new_resource.action.to_s})\s.*#{@new_resource.source || 'Anywhere'}$/i
end

