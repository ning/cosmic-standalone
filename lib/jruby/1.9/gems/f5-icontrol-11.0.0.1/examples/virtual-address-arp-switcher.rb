#!/usr/bin/ruby

# == Synopsis
#
# virtual-address-arp-switcher - quickly swap virtual addresses between BIG-IPs
#
#   The virtual-address-arp-switcher script is used to quickly and efficiently migrate virtual addresses from one BIG-IP to another. The BIG-IP that is active and currently holds the ARP-enabled virtual address is referred to as the 'source'. The BIG-IP holding the same virtual address with ARP disabled is the 'target'. This script will login to both units, ensure that the virtual address is present on both units and that the ARP setting for both the source and target are in their correct state. A delay can be inserted during which both virtual addresses are in the disabled state. The delay can be set to the ARP cache timeout to ensure that duplicates ARP entries do not exist in the caches. 
#
# == Usage
#
# virtual-address-arp-switcher [OPTIONS]
#
# -h, --help:
#    show help
#
# --bigip-address-source, -b [hostname]:
#    specify the hostname or IP address for source BIG-IP
#
# --bigip-user-source, -u [username]:
#    username for source BIG-IP
#
# --bigip-pass-source, -p [password]:
#    password for source BIG-IP
#
# --bigip-address-target [hostname]:
#    specify the target BIG-IP address
#
# --bigip-user-target [username]:
#    username for target BIG-IP, by default assumes same as source BIG-IP 
#
# --bigip-pass-target [password]:
#    password for target BIG-IP, by default assumes same as source BIG-IP
#
# --virtual-address, -v [ip address]:
#    virtual address for which to disable and enable ARP
#
# --delay, -d [seconds]:
#    delay between disabling ARP on the source BIG-IP and enabling on target


require 'rubygems'
require 'f5-icontrol'
require 'getoptlong'
require 'rdoc/usage'

options = GetoptLong.new(
  [ '--bigip-address-source', '-b', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--bigip-user-source',    '-u', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--bigip-pass-source',    '-p', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--bigip-address-target',       GetoptLong::REQUIRED_ARGUMENT ],
  [ '--bigip-user-target',          GetoptLong::REQUIRED_ARGUMENT ],
  [ '--bigip-pass-target',          GetoptLong::REQUIRED_ARGUMENT ],
  [ '--virtual-address',      '-v', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--delay',                '-d', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--help',                 '-h', GetoptLong::NO_ARGUMENT ]
)

# set inital values

bigip_address_source = ''
bigip_user_source = ''
bigip_pass_source = ''
bigip_address_target = ''
bigip_user_target = ''
bigip_pass_target = ''
virtual_address = ''
delay = 0

options.each do |option, arg|
  case option
    when '--bigip-address-source'
      bigip_address_source = arg
    when '--bigip-user-source'
      bigip_user_source = arg
    when '--bigip-pass-source'
      bigip_pass_source = arg
    when '--bigip-address-target'
      bigip_address_target = arg
    when '--bigip-user-target'
      bigip_user_target = arg
    when '--bigip-pass-target'
      bigip_pass_target = arg
    when '--virtual-address'
      if arg =~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/
        virtual_address = arg
      end
    when '--delay'
      delay = arg.to_i
    when '--help'
      RDoc::usage
  end
end

RDoc::usage if bigip_address_source.empty? \
  or bigip_user_source.empty? \
  or bigip_pass_source.empty? \
  or bigip_address_target.empty? \
  or virtual_address.empty?

bigip_user_target = bigip_user_source if bigip_user_target.empty?
bigip_pass_target = bigip_pass_source if bigip_pass_target.empty?

# Initiate SOAP RPC connection to BIG-IP

begin
  bigip_source = F5::IControl.new(bigip_address_source, bigip_user_source, bigip_pass_source, ['LocalLB.VirtualAddress']).get_interfaces
rescue 
  puts 'ERROR: Connection error occured while connecting to the source BIG-IP at '
  puts "#{bigip_address_source}."
  exit 1
end

begin
  bigip_target = F5::IControl.new(bigip_address_target, bigip_user_target, bigip_pass_target, ['LocalLB.VirtualAddress']).get_interfaces
rescue 
  puts 'ERROR: Connection error occured while connecting to the target BIG-IP at '
  puts "#{bigip_address_target}."
  exit 1
end

# Make sure that the virtual address is available on both BIG-IPs

unless bigip_source['LocalLB.VirtualAddress'].get_list.include? virtual_address
  puts 'ERROR: The source BIG-IP does not contain the virtual address provided.'
  exit 1
end

unless bigip_target['LocalLB.VirtualAddress'].get_list.include? virtual_address
  puts 'ERROR: The target BIG-IP does not contain the virtual address provided.'
  exit 1
end

# Ensure that the ARP state of both addresses is correct

bigip_source_arp_state = bigip_source['LocalLB.VirtualAddress'].get_arp_state(virtual_address).to_s
bigip_target_arp_state = bigip_target['LocalLB.VirtualAddress'].get_arp_state(virtual_address).to_s

if bigip_source_arp_state == 'STATE_DISABLED' and bigip_target_arp_state == 'STATE_ENABLED'
  puts 'ERROR: ARP is currently disabled for the virtual address on the source BIG-IP and enabled on the target. It appears that the two are reversed. Please read the help message for more information on which unit should be the source and the other the target.'
  exit 1
elsif (bigip_source_arp_state and bigip_target_arp_state) == 'STATE_ENABLED'
  puts 'ERROR: ARP is enabled for the virtual address on both BIG-IPs. It is likely that there is an IP address conflict at the moment.'
  exit 1
elsif bigip_source_arp_state == 'STATE_DISABLED'
  puts 'ERROR: ARP is currently disabled for the virtual address on the source BIG-IP and needs to be enabled to proceed.'
  exit 1
elsif bigip_target_arp_state == 'STATE_ENABLED'
  puts 'ERROR: ARP is currently enabled for the virtual address on the target BIG-IP and needs to be disabled to proceed.'
  exit 1
end

# Everything looks good so far, confirm the swap, then proceed 

puts "Virtual address details"
puts "-" * 20
puts "Virtual address:  #{virtual_address}"
puts "Current location: #{bigip_address_source}"
puts "Future location:  #{bigip_address_target}"
puts "Delay:            #{delay} seconds"

answer = ''
print "\nAre you sure you want to proceed? (no/yes) "

STDOUT.flush
answer = STDIN.gets.chomp
exit unless answer == "yes"

# Begin the swap

puts "WARNING: Commencing swap! Do not exit script! Wait for exit!"

puts "INFO: Disabling ARP for virtual address #{virtual_address} on #{bigip_address_source}..."
bigip_source['LocalLB.VirtualAddress'].set_arp_state([virtual_address], ['STATE_DISABLED'])

puts "INFO: Sleeping for #{delay} seconds..."
sleep delay

puts "INFO: Enabling ARP for virtual address #{virtual_address} on #{bigip_address_target}..."
bigip_target['LocalLB.VirtualAddress'].set_arp_state([virtual_address], ['STATE_ENABLED'])
