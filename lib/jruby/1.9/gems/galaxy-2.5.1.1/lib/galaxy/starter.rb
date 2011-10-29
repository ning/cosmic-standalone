require 'fileutils'
require 'logger'

module Galaxy
  
  class Starter
    
    def initialize log
      @log = log
    end
    
    def start! path
      begin 
        system "#{xnctl_path path} start"
        case $?.exitstatus
        when 0:
          "running"
        else 
          "stopped"
        end
      rescue => e
        @log.warn e
        "unknown"
      end
    end
    
    def restart! path
      begin 
        system "#{xnctl_path path} restart"
        case $?.exitstatus
        when 0:
          "running"
        else 
          "stopped"
        end
      rescue => e
        @log.warn e
        "unknown"
      end
    end
    
    def stop! path
      begin 
        system "#{xnctl_path path} stop"
        case $?.exitstatus
        when 0:
          "stopped"
        else 
          "running"
        end
      rescue => e
        @log.warn e
        "unknown"
      end
    end
    
    def status path
      begin 
        if not path.nil? and File.exists? xnctl_path(path)
          system("#{xnctl_path path} status")
          case $?.exitstatus
            when 1
              "running"
            when 0
              "stopped"
            else
              "unknown"
            end
        end
      rescue => e
        @log.warn e 
        "unknown"
      end
    end
    
    private
    def xnctl_path path
      xnctl = File.join(path, "bin", "launcher")
      xnctl = "/bin/sh #{xnctl}" unless FileTest.executable? xnctl
      xnctl
    end
    
  end
end