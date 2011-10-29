#!/usr/bin/ruby

require "rubygems"
require "f5-icontrol"
require "net/scp"
require "progressbar"
require "getoptlong"

STDOUT.sync

options = GetoptLong.new(
  [ "--bigip-address",    "-b", GetoptLong::REQUIRED_ARGUMENT ],
  [ "--bigip-web-user",   "-u", GetoptLong::REQUIRED_ARGUMENT ],
  [ "--bigip-web-pass",   "-p", GetoptLong::REQUIRED_ARGUMENT ],
  [ "--bigip-shell-user", "-s", GetoptLong::REQUIRED_ARGUMENT ],
  [ "--bigip-shell-pass",       GetoptLong::REQUIRED_ARGUMENT ],
  [ "--install-image",    "-f", GetoptLong::REQUIRED_ARGUMENT ],
  [ "--hd-slot",          "-h", GetoptLong::REQUIRED_ARGUMENT ],
  [ "--skip-upload",      "-x", GetoptLong::NO_ARGUMENT ],
  [ "--help",                   GetoptLong::NO_ARGUMENT ]
)

def usage
  puts $0 + " -b <BIG-IP address> -u <BIG-IP user>"
  puts "  -b (--bigip-address)    BIG-IP management-accessible address"
  puts "  -u (--bigip-web-user)   BIG-IP web interface username (must have administrator privileges; defaults to 'admin')"
  puts "  -p (--bigip-web-pass)   BIG-IP web interface user password (will prompt if not specified)"
  puts "  -s (--bigip-shell-user) BIG-IP Secure Shell (SSH) username (must have root privileges; defaults to 'root')"
  puts "     (--bigip-shell-pass) BIG-IP Secure Shell user password (will prompt if not specified)"
  puts "  -f (--install-image)    path of ISO image for BIG-IP install image"
  puts "  -x (--skip-upload)      skip uploading of ISO image (already on BIG-IP in /shared/images)"
  puts "  -h (--hd-slot)          installation slot (HD slot) to install to"
  puts "     (--help)             shows this help/usage dialog"

  exit
end

# initial command argument values

bigip_address    = ''
bigip_web_user   = 'admin'
bigip_web_pass   = ''
bigip_shell_user = 'root'
bigip_shell_pass = ''
install_image    = ''
skip_upload      = false
hd_slot          = ''
verbose          = false

# the color_code variable must be global to be read within the format_text method

options.each do |option, arg|
  case option
    when "--bigip-address"
      bigip_address = arg
    when "--bigip-web-user"
      bigip_web_user = arg
    when "--bigip-web-pass"
      bigip_web_pass = arg
    when "--bigip-shell-user"
      bigip_shell_user = arg
    when "--bigip-shell-pass"
      bigip_shell_pass = arg
    when "--install-image"
      if File.exists? arg
        install_image = arg
      else
        puts "ERROR: install image does not exist - #{arg}"
        exit
      end
    when "--skip-upload"
      skip_upload = true
    when "--hd-slot"
      hd_slot = arg
    when "--help"
      usage
  end
end

usage if bigip_address.empty? or install_image.empty? or hd_slot.empty?

# prompt for web interface and shell users' password(s) if not provided 

if bigip_web_pass.empty?
  print "Web user's (#{bigip_web_user}) password: "
  system("stty", "-echo")
  bigip_web_pass = gets.chomp
  system("stty", "echo")
  puts
end

unless skip_upload
  if bigip_shell_pass.empty?
    print "Shell user's (#{bigip_shell_user}) password: "
    system("stty", "-echo")
    bigip_shell_pass = gets.chomp
    system("stty", "echo")
    puts
  end
  
  puts "Copying #{File.basename(install_image)} to #{bigip_address}..."
  
  Net::SCP.start(bigip_address, bigip_shell_user, :password => bigip_shell_pass.chomp, :auth_methods =>["keyboard-interactive" ] ) do |scp|
    # upload a file to a remote server
    pbar = ProgressBar.new(File.basename(install_image), 100)
  
    scp.upload!(install_image, "/shared/images/.") do |chunk, image, sent, total|
      pbar.set((sent*100)/total)
    end
  
    pbar.finish
  end
end

puts "Install image details"
puts "-" * 20
install_image_details = install_image.scan /(\w+)-(\d+\.\d+\.\d+)\.(\d+.\d+)/

puts "Product: #{install_image_details[0][0]}"
puts "Version: #{install_image_details[0][1]}"
puts "Build:   #{install_image_details[0][2]}"

bigip = F5::IControl.new(bigip_address, bigip_web_user, bigip_web_pass, ["System.SoftwareManagement", "System.Failover"]).get_interfaces

answer = ''

if bigip["System.Failover"].get_failover_state == "FAILOVER_STATE_ACTIVE"
  question = "\nWARNING: you are installing on an ACTIVE unit! Are you sure you want to proceed? (no/yes) "
else
  question = "\nAre you sure you want to proceed with installation of this image? (no/yes) "
end

print question
STDOUT.flush
answer = gets.chomp
exit unless answer == "yes"

puts "\nInstalling #{File.basename(install_image)} on #{bigip_address}...\n"

bigip["System.SoftwareManagement"].install_software_image(hd_slot, install_image_details[0][0], install_image_details[0][1], install_image_details[0][2])

puts "#{install_image_details[0][0]} version #{install_image_details[0][1]}, build #{install_image_details[0][2]} has been successfully installed on #{bigip_address}..."
