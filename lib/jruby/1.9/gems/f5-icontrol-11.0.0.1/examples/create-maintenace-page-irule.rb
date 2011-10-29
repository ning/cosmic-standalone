#!/usr/bin/ruby

require "rubygems"
require "f5-icontrol"
require "getoptlong"

options = GetoptLong.new(
  [ "--bigip-address",  "-b", GetoptLong::REQUIRED_ARGUMENT ],
  [ "--bigip-user",     "-u", GetoptLong::REQUIRED_ARGUMENT ],
  [ "--bigip-pass",     "-p", GetoptLong::REQUIRED_ARGUMENT ],
  [ "--html-file",      "-f", GetoptLong::REQUIRED_ARGUMENT ],
  [ "--maintenance-vs", "-v", GetoptLong::OPTIONAL_ARGUMENT ],
  [ "--irule-name",     "-n", GetoptLong::OPTIONAL_ARGUMENT ],
  [ "--help",           "-h", GetoptLong::NO_ARGUMENT ]
)

def usage 
  puts $0 + " -b <BIG-IP address> -u <BIG-IP user> -f <maintenance page HTML file>"
  puts "  -b (--bigip-address)    BIG-IP management-accessible address"
  puts "  -u (--bigip-user)       BIG-IP username"
  puts "  -p (--bigip-pass)       BIG-IP password (will prompt if left blank)"
  puts "  -f (--html-file)        source HTML file for maintenance page"
  puts "  -v (--maintenance-vs)   virtual server to apply maintenance page (will immediiately put virtual server in maintenance mode)"
  puts "  -n (--irule-name)       name of maintenance iRule (defaults to maintenance_page_<html file name>)"
  puts "  -h (--help)             shows this help/usage dialog"

  exit
end

# initial parameter values

bigip_address = ''
bigip_user = ''
bigip_pass = ''
maintenance_html_file = ''
maintenance_vs = ''
maintenance_irule_name = ''

options.each do |option, arg|
  case option
    when "--bigip-address"
      bigip_address = arg
    when "--bigip-user"
      bigip_user = arg
    when "--bigip-pass"
      bigip_pass = arg
    when "--html-file"
      maintenance_html_file = arg
    when "--maintenance-vs"
      maintenance_vs = arg
    when "--irule-name"
      maintenance_irule_name = arg
    when "--help"
      usage
  end
end

# at the very least, the user should provide be BIG-IP address and username

usage if bigip_address.empty? or bigip_user.empty? or maintenance_html_file.empty?

# make sure that the maintenance page source HTML file exists, if not display error and exit

unless File.exists? maintenance_html_file
  puts "Error: #{maintenance_html_file} could not be located. Check the path and try again."
  exit 1
end

# if no iRule name is specified, built the default

if maintenance_irule_name.empty?
  maintenance_irule_name = "maintenance_page_#{File.basename(maintenance_html_file).gsub('.', '_')}"
end

# if no BIG-IP password is provided, prompt for it

if bigip_pass.empty?
  puts "Please enter the BIG-IPs password..."
  print "Password: "
  system("stty", "-echo")
  bigip_pass = gets.chomp
  system("stty", "echo")
end

# create iControl interfaces

bigip = F5::IControl.new(bigip_address, bigip_user, bigip_pass, ["LocalLB.VirtualServer", "LocalLB.Rule"]).get_interfaces

puts "Connected to BIG-IP at #{bigip_address} with user '#{bigip_user}'..."
puts

# ensure that that virtual server exists before proceeding 

unless maintenance_vs.empty?
  unless bigip["LocalLB.VirtualServer"].get_list.include? maintenance_vs
    puts "Error: virtual server '#{maintenance_vs}' could not be located on BIG-IP"
    exit
  end
end

maintenance_irule = "priority 1\n\nwhen HTTP_REQUEST {\n    HTTP::respond 200 content {#{File.read(maintenance_html_file)}}\n}"

irule_definition = {"rule_name" => maintenance_irule_name, "rule_definition" => maintenance_irule}

if bigip["LocalLB.Rule"].get_list.include? maintenance_irule_name
  puts "An iRule named '#{maintenance_irule_name}' already exists. Would you like to replace it? (yes/no)"
  answer = gets

  if answer == "yes\n"
    puts "Updating '#{maintenance_irule_name}' on BIG-IP..."
    bigip["LocalLB.Rule"].modify_rule([irule_definition])
  else
    puts "Nothing to do. Exiting..."
    exit
  end
else
  puts "Creating iRule '#{maintenance_irule_name}' on BIG-IP..."
  bigip["LocalLB.Rule"].create([irule_definition])
end

# assemble a list of iRules already assigned to virtual server

vs_irules = []
bigip["LocalLB.VirtualServer"].get_rule(maintenance_vs)[0].each { |irule| vs_irules << irule['rule_name'] } unless maintenance_vs.empty?

unless maintenance_vs.empty? or vs_irules.include? maintenance_irule_name
  puts "Are you absolutely sure that you want to enable the maintenance iRule for virtual server '#{maintenance_vs}'? (yes/no)"
  answer = gets

  if answer == "yes\n"
    puts "Applying maintenance page iRule to virtual server '#{maintenance_vs}'..."
    bigip["LocalLB.VirtualServer"].add_rule([maintenance_vs], [[{"rule_name" => maintenance_irule_name, "priority" => 1}]])
  end
end

puts "Done!"
