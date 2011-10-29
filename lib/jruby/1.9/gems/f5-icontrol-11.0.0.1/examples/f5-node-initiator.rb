#!/usr/bin/ruby
#
# == Synopsis
#
# f5-node-initiator - Quickly add nodes to pools
#
# == Usage
#
# f5-node-initiator [OPTIONS]
#
# -h, --help:
#    show help
#
# --bigip-address, -b [hostname]:
#    specify the destination BIG-IP for virtual and pool creation
#
# --bigip-user, -u [username]:
#    username for destination BIG-IP
#
# --bigip-pass, -p [password]:
#    password for destination BIG-IP
#
# --pool-name, -n [name]: 
#    name of pool to add node to
#
# --node-definition, -d [ip address:port]:
#    definition for node being added to pool, example: 10.2.1.1:443


require 'rubygems'
require 'f5-icontrol'
require 'getoptlong'
require 'rdoc/usage'

options = GetoptLong.new(
  [ '--bigip-address',    '-b', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--bigip-user',       '-u', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--bigip-pass',       '-p', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--pool-name',        '-n', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--node-definition',  '-d', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--help',             '-h', GetoptLong::NO_ARGUMENT ]
)

bigip_address = ''
bigip_user = ''
bigip_pass = ''
pool_name = ''
node_address = ''
node_port = 80

options.each do |option, arg|
  case option
    when '--bigip-address'
      bigip_address = arg
    when '--bigip-user'
      bigip_user = arg
    when '--bigip-pass'
      bigip_pass = arg
    when '--pool-name'
      pool_name = arg
    when '--node-definition'
      if arg =~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}:\d+/
        node_address = arg.split(':')[0]
        node_port = arg.split(':')[1]
      end
    when '--help'
      RDoc::usage
  end
end

RDoc::usage if bigip_address.empty? or bigip_user.empty? or bigip_pass.empty? or pool_name.empty? or node_address.empty?

# Initiate SOAP RPC connection to BIG-IP
bigip = F5::IControl.new(bigip_address, bigip_user, bigip_pass, ['LocalLB.Pool']).get_interfaces

# Insure that target pool exists
unless bigip['LocalLB.Pool'].get_list.include? pool_name
  puts 'ERROR: target pool "' + pool_name +'" does not exist'
  exit 1
end

# collect list of existing pool member definitions
pool_members = bigip['LocalLB.Pool'].get_member([ pool_name ])[0].collect do |pool_member|
  pool_member['address'] + ':' + pool_member['port'].to_s
end

# don't attempt to add member if it already exists
unless pool_members.include?(node_address + ':' + node_port.to_s)
  bigip['LocalLB.Pool'].add_member([ pool_name ], [[{ 'address' => node_address, 'port' => node_port.to_i }]])
end
