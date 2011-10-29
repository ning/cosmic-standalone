#!/usr/bin/ruby

require "rubygems"
require "f5-icontrol"

def usage 
  puts $0 + " <BIG-IP address> <BIG-IP user> <BIG-IP password>"
  exit
end

usage if $*.size < 3

bigip = F5::IControl.new($*[0], $*[1], $*[2], ["System.SystemInfo"]).get_interfaces

puts bigip["System.SystemInfo"].get_version
