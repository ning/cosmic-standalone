#!/usr/bin/ruby
#
# == Synopsis
#
# create-http-virtual-and-pool - Quickly create an HTTP virtual and pool
#
# == Usage
#
# create-http-virtual-and-pool [OPTIONS]
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
# --vs-name, -n [name]:
#    name of virtual server to be created
#
# --vs-address, -a [IP address]:
#    destination IP address of virtual server to be created
#
# --pool-name [name]: 
#    optional argument: name of pool to be created; p.[virtual server name]_http
#      will be used by default
#
# --pool-members, -m [<pool member 1>,<pool member 2> ...] *no spaces
#    optional argument: IP addresses of pool members; virtual will not funtion
#      without pool members

require "rubygems"
require "f5-icontrol"
require "getoptlong"
require "rdoc/usage"

options = GetoptLong.new(
  [ "--bigip-address",  "-b", GetoptLong::REQUIRED_ARGUMENT ],
  [ "--bigip-user",     "-u", GetoptLong::REQUIRED_ARGUMENT ],
  [ "--bigip-pass",     "-p", GetoptLong::REQUIRED_ARGUMENT ],
  [ "--vs-name",        "-n", GetoptLong::REQUIRED_ARGUMENT ],
  [ "--vs-address",     "-a", GetoptLong::REQUIRED_ARGUMENT ],
  [ "--pool-name",            GetoptLong::OPTIONAL_ARGUMENT ],
  [ "--pool-members",   "-m", GetoptLong::OPTIONAL_ARGUMENT ],
  [ "--help",           "-h", GetoptLong::NO_ARGUMENT ]
)

bigip_address = ''
bigip_user = ''
bigip_pass = ''
vs_name = ''
vs_address = ''
pool_name = ''
pool_members = []

options.each do |option, arg|
  case option
    when "--bigip-address"
      bigip_address = arg
    when "--bigip-user"
      bigip_user = arg
    when "--bigip-pass"
      bigip_pass = arg
    when "--vs-name"
      vs_name = arg
    when "--vs-address"
      vs_address = arg
    when "--pool-name"
      pool_name = arg
    when "--pool-members"
      arg.gsub(/[^\d,\.]/, '').split(',').delete_if { |x| x.empty? }.each do |x|
        pool_members << {"address" => x, "port" => 80}
      end
    when "--help"
      RDoc::usage
  end
end

RDoc::usage if bigip_address.empty? or bigip_user.empty? or bigip_pass.empty? or vs_name.empty? or vs_address.empty?

# Initiate SOAP RPC connection to BIG-IP
bigip = F5::IControl.new(bigip_address, bigip_user, bigip_pass, ["LocalLB.VirtualServer", "LocalLB.Pool"]).get_interfaces
puts 'Connected to BIG-IP at "' + bigip_address + '" with username "' + bigip_user + '" and password "' + bigip_pass + '"...'

# Assign pool name is not provided by user
pool_name = "p.#{vs_name}_http" if pool_name.empty?

# Create target HTTP pool
bigip["LocalLB.Pool"].create(pool_name, 'LB_METHOD_ROUND_ROBIN', [pool_members])
puts 'Created pool named "' + pool_name + '" with destination address ' + vs_address + '...'

# Assign default http and gateway_icmp monitors
bigip["LocalLB.Pool"].set_monitor_association(["pool_name" => pool_name, "monitor_rule" => {"type" => "MONITOR_RULE_TYPE_AND_LIST", "quorum" => 0, "monitor_templates" => ["http", "gateway_icmp"]}])
puts 'Assigned "http" and "gateway_icmp" monitors to "' + pool_name + '" pool...'

# Create necessary virtual server parameters
vs_definition = [{"name" => vs_name, "address" => vs_address, "port" => 80, "protocol" => "PROTOCOL_TCP"}]
vs_wildmask = "255.255.255.255"
vs_resources = [{"type" => "RESOURCE_TYPE_POOL", "default_pool_name" => pool_name}]
vs_profiles = [[{"profile_context" => "PROFILE_CONTEXT_TYPE_ALL", "profile_name" => "http"}]]

# Create new virtual server
bigip["LocalLB.VirtualServer"].create(vs_definition, vs_wildmask, vs_resources, vs_profiles)
puts 'Created virtual server named "' + vs_name + '" with destination address ' + vs_address + '...'

# Set SNAT automap for new virtual server
bigip["LocalLB.VirtualServer"].set_snat_automap([vs_name])
puts 'Set SNAT automap for virtual server "' + vs_name + '"'
