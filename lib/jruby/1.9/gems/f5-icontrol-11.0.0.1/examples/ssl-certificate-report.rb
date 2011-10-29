#!/usr/bin/ruby

require "rubygems"
require "f5-icontrol"
require "getoptlong"

options = GetoptLong.new(
  [ "--bigip-address",  "-b", GetoptLong::REQUIRED_ARGUMENT ],
  [ "--bigip-user",     "-u", GetoptLong::REQUIRED_ARGUMENT ],
  [ "--bigip-pass",     "-p", GetoptLong::REQUIRED_ARGUMENT ],
  [ "--cert-name",      "-n", GetoptLong::OPTIONAL_ARGUMENT ],
  [ "--cert-list",      "-l", GetoptLong::NO_ARGUMENT ],
  [ "--watermark-days", "-d", GetoptLong::OPTIONAL_ARGUMENT ],
  [ "--no-color",       "-c", GetoptLong::NO_ARGUMENT ],
  [ "--verbose",        "-v", GetoptLong::OPTIONAL_ARGUMENT ],
  [ "--help",           "-h", GetoptLong::NO_ARGUMENT ]
)

def usage 
  puts $0 + " -b <BIG-IP address> -u <BIG-IP user>"
  puts "  -b (--bigip-address)   BIG-IP management-accessible address"
  puts "  -u (--bigip-user)      BIG-IP username"
  puts "  -p (--bigip-pass)      BIG-IP password (will prompt if left blank"
  puts "  -n (--cert-name)       name of certificate to display (display all by default)"
  puts "  -l (--cert-list)       list of certificates managed by the BIG-IP"
  puts "  -d (--watermark-days)  certificates expiring inside this number of days will"
  puts "                             be marked as \"expiring soon\", default is 30 days"
  puts "  -c (--no-color)        disable color coding for the shell (useful if piping"
  puts "                             output to less or are using Windows)"
  puts "  -v (--verbose)         show all certificate information (brief by default)"
  puts "  -h (--help)            shows this help/usage dialog"

  exit
end

# initial parameter values

bigip_address = ''
bigip_user = ''
bigip_pass = ''
cert_name = ''
cert_list = false
watermark_days = 30
verbose = false

# the color_code variable must be global to be read within the format_text method

$color_code = true

options.each do |option, arg|
  case option
    when "--bigip-address"
      bigip_address = arg
    when "--bigip-user"
      bigip_user = arg
    when "--bigip-pass"
      bigip_pass = arg
    when "--cert-name"
      cert_name = arg
    when "--cert-list"
      cert_list = true
    when "--watermark-days"
      arg = arg.to_i
      watermark_days = arg
    when "--no-color"
      $color_code = false
    when "--verbose"
      verbose = true
    when "--help"
      usage
  end
end

usage if bigip_address.empty? or bigip_user.empty?

if bigip_pass.empty?
  puts "Please enter the BIG-IPs password..."
  print "Password: "
  system("stty", "-echo")
  bigip_pass = gets.chomp
  system("stty", "echo")
end

bigip = F5::IControl.new(bigip_address, bigip_user, bigip_pass, ["Management.KeyCertificate"]).get_interfaces

def format_text(text, code)
  if $color_code
    "#{code}#{text}\e[00m"
  else
    text
  end
end

def red(text)
  format_text(text, "\e[01;31m")
end

def green(text)
  format_text(text, "\e[01;32m")
end

def yellow(text)
  format_text(text, "\e[01;33m")
end

def bold(text)
  format_text(text, "\e[1m")
end

def underline(text)
  format_text(text, "\e[4m")
end

def bold_underline(text)
  format_text(text, "\e[4;1m")
end

def cert_validity_label(expire_text)
  case expire_text
    when "VTYPE_CERTIFICATE_VALID"
      green("valid")
    when "VTYPE_CERTIFICATE_EXPIRED"
      red("expired")
    when "VTYPE_CERTIFICATE_WILL_EXPIRE"
      yellow("expiring soon")
    when "VTYPE_CERTIFICATE_INVALID" 
      red("invalid")
    else
      yellow("unknown")
  end
end

def key_strength_label(key_length)
  case(key_length)
    when 0..1023
      red("low")
    when 1024..2047
      yellow("medium")
    else
      green("strong")
  end
end

def key_type_label(key_type)
  case key_type
    when "KTYPE_RSA_PRIVATE"
      "RSA private key"
    when "KTYPE_RSA_PUBLIC"
      "RSA public key"
    when "KTYPE_DSA_PRIVATE"
      "DSA private key"
    when "KTYPE_DSA_PUBLIC"
      "DSA public key"
    else
      "Unkown"
  end
end

# collect certificate properties

certs = {}

bigip["Management.KeyCertificate"].get_certificate_list("MANAGEMENT_MODE_DEFAULT").each do |cert|
  id = cert['certificate']['cert_info']['id']

  certs[id] = {}

  # general properties

  certs[id]['expires'] = Time.at(cert['certificate']['expiration_date']).strftime("%b %e, %Y")
  certs[id]['version'] = cert['certificate']['version']
  certs[id]['serial'] = cert['certificate']['serial_number']
  certs[id]['serial'] = 'unavailable' if certs[id]['serial'].empty?

  # subject and issuers properties

  ['subject', 'issuer'].each do |x|
    certs[id][x] = {}
    ['common_name', 'organization_name', 'division_name', 'locality_name', 'state_name', 'country_name'].each do |y|

      certs[id][x][y] = cert['certificate'][x][y]
    end
  end
  
  certs[id]['key'] = {}
  certs[id]['key']['length'] = cert['certificate']['bit_length']
  certs[id]['key']['length_text'] = key_strength_label(cert['certificate']['bit_length'].to_i)
  certs[id]['key']['type'] = key_type_label(cert['certificate']['key_type'])
end

# collect certificate validity information

validity_states = bigip["Management.KeyCertificate"].certificate_check_validity('MANAGEMENT_MODE_DEFAULT', certs.keys, ([watermark_days] * certs.keys.size))

x = 0

certs.each do |id,cert|
  cert['expire_text'] = cert_validity_label(validity_states[x])
  x += 1
end

# display BIG-IP information

puts bold("\nConnected to BIG-IP at #{bigip_address} with user '#{bigip_user}'...")

# if user only wants list, display it and exit

if cert_list
  puts
  puts underline("Available certificates\n")
  puts certs.keys.sort.collect { |id| id = "  " + id }
  puts
  exit
end

unless cert_name.empty?
  if certs.key? cert_name
    certs = { cert_name => certs[cert_name] }
  else
    puts "Error: could not locate a certificate by that name, try '-l' for a list"
    exit
  end
end

puts bold_underline(" " * 80)
puts

certs.keys.sort.each do |id|
  puts underline("General Properties")
  puts "\t" + bold("Name: ") + id
  puts "\t" + bold("Certificate Subject(s): ") + certs[id]['subject']['common_name'] + ", " + certs[id]['subject']['organization_name'] + "\n\n"

  puts underline("Certificate Properties")
  puts "\t" + bold("Expires: \t") + certs[id]['expires'] + " (" + certs[id]['expire_text'] + ")"

  puts "\t" + bold("Version: \t") + certs[id]['version'].to_s
  puts "\t" + bold("Serial: \t") + certs[id]['serial']

  if verbose
    ['subject', 'issuer'].each do |section|
      puts "\t" + bold(section.capitalize) + ":"

      subsections = { 'Common Name' => 'common_name', \
        'Organization' => 'organization_name', \
        'Division' => 'division_name', \
        'Locality' => 'locality_name', \
        'State (Prov)' => 'state_name', \
        'Country' => 'country_name' } \

      subsections.each do |key, subsection|
        puts "\t\t\t" + key + ": \t" + certs[id][section][subsection] unless certs[id][section][subsection].empty?
      end
    end

    puts
  end

  puts underline("Public Key Properties")
  puts "\t" + bold("Key Type: ") + certs[id]['key']['type'] 
  puts "\t" + bold("Size: ") + certs[id]['key']['length'].to_s + " (" + certs[id]['key']['length_text'] + ")" 

  puts
  puts bold_underline(" " * 80)
  puts
end
