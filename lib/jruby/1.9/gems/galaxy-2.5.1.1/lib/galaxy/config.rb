require 'fileutils'
require 'logger'
require 'galaxy/host'

module Galaxy
  module Config
    def read_config_file config_file
      config_file = config_file || ENV['GALAXY_CONFIG']
      unless config_file.nil? or config_file.empty?
        raise "Cannot find configuration file: #{config_file}" unless File.exist?(config_file)
      end
      config_files = [config_file, '/etc/galaxy.conf', '/usr/local/etc/galaxy.conf'].compact
      config_files.each do |config_file|
        begin
          File.open config_file, "r" do |f|
            return YAML.load(f.read)
          end
        rescue Errno::ENOENT
        end
      end
      # Fall through to empty config hash
      return { }
    end
    module_function :read_config_file
  end
  
  class AgentConfigurator

    def initialize config
      @config = config
      @config_from_file = Galaxy::Config::read_config_file(config.config_file)
    end

    def correct key
      case key
        when :deploy_dir
          "deploy-to"
        when :data_dir
          "data-dir"
        when :announce_interval
          "announce-interval"
        else
          key
      end
    end

    def guess key
      val = self.send key
      puts "    --#{correct key} #{val}" if @config.verbose
      val
    end

    def configure
      puts "startup configuration" if @config.verbose
      {
        :host => guess(:host),
        :console => guess(:console),
        :repository => guess(:repository),
        :binaries => guess(:binaries),
        :deploy_dir => guess(:deploy_dir),
        :verbose => @config.verbose || false,
        :data_dir => guess(:data_dir),
        :log => guess(:log),
        :log_level => guess(:log_level),
        :pid_file => guess(:pid_file),
        :user => guess(:user),
        :announce_interval => guess(:announce_interval)
      }
    end

    def log
      @log ||= @config.log || @config_from_file['galaxy.agent.log'] || "SYSLOG"
    end

    # convert the input parameter to a Logger class log level and return it, else return nil
    def log_level
      @log_level ||= begin
        log_level = @config.log_level || @config_from_file['galaxy.agent.log-level'] || 'INFO'
        case log_level
        when "DEBUG"
          Logger::DEBUG
        when "INFO"
          Logger::INFO
        when "WARN"
          Logger::WARN
        when "ERROR"
          Logger::ERROR
        end
      end
    end

    def pid_file
      @pid_file ||= @config.pid_file || @config_from_file['galaxy.agent.pid-file'] || '/var/tmp/galaxy-agent.pid'
    end

    def user
      @user ||= @config.user || @config_from_file['galaxy.agent.user'] || nil
    end

    def guess_base
      @base ||= begin
        if @config.env and @config.env =~ /xn?/
          "#{@config.env}.ningops.net"
        elsif @config.env
          "#{@config.env}.ninginc.com"
        elsif host =~ /^(?:\w+\.*)(\w+\.ningops\.net)$/
          $1
        elsif host =~ /^(?:\w+\.)*(\w+\.ninginc\.com)$/
          $1
        end
      end
    end

    def host
      @host ||= @config.host || @config_from_file['galaxy.agent.host'] || `hostname`.strip
    end

    def console
      @console ||= @config.console || @config_from_file['galaxy.agent.console'] || "galaxy.#{guess_base}"
    end

    def repository
      @repository ||= @config.repository || @config_from_file['galaxy.agent.config-root'] || "http://repo.#{guess_base}/config"
    end

    def binaries
      @binaries ||= @config.binaries || @config_from_file['galaxy.agent.binaries-root'] || "http://repo.#{guess_base}/release"
    end

    def deploy_dir
      @deploy_dir ||= @config.deploy_dir || @config_from_file['galaxy.agent.deploy-dir'] || "#{HostUtils.avail_path}/galaxy-agent/deploy"
      FileUtils.mkdir_p(@deploy_dir) unless File.exists? @deploy_dir
      @deploy_dir
    end

    def data_dir
      @data_dir ||= @config.data_dir || @config_from_file['galaxy.agent.data-dir'] || "#{HostUtils.avail_path}/galaxy-agent/data"
      FileUtils.mkdir_p(@data_dir) unless File.exists? @data_dir
      @data_dir
    end
  
    def announce_interval
      @announce_interval ||= @config.announce_interval || @config_from_file['galaxy.agent.announce-interval'] || 60
      @announce_interval = @announce_interval.to_i
    end
  end
  
  class ConsoleConfigurator
  
    def initialize config
      @config = config
      @config_from_file = Galaxy::Config::read_config_file(config.config_file)
    end
  
    def correct key
      case key
        when :data_dir
          return :data
        when :deploy_dir
          "deploy-to"
        when :ping_interval
          "ping-interval"
        else
          key
      end
    end

    def guess key
      val = self.send key
      puts "    --#{correct key} #{val}" if @config.verbose
      val
    end

    def configure
      puts "startup configuration" if @config.verbose
      {
        :environment => guess(:environment),
        :verbose => @config.verbose || false,
        :log => guess(:log),
        :log_level => guess(:log_level),
        :pid_file => guess(:pid_file),
        :user => guess(:user),
        :host => guess(:host),
        :announcement_url => guess(:announcement_url),
        :ping_interval => guess(:ping_interval)
      }
    end

    def log
      @log ||= @config.log || @config_from_file['galaxy.console.log'] || "SYSLOG"
    end

    # convert the input parameter to a Logger class log level and return it, else return nil
    def log_level
      @log_level ||= begin
        log_level = @config.log_level || @config_from_file['galaxy.console.log-level'] || 'INFO'
        case log_level
        when "DEBUG"
          Logger::DEBUG
        when "INFO"
          Logger::INFO
        when "WARN"
          Logger::WARN
        when "ERROR"
          Logger::ERROR
        end
      end
    end

    def pid_file
      @pid_file ||= @config.pid_file || @config_from_file['galaxy.console.pid-file'] || '/var/tmp/galaxy-console.pid'
    end

    def user
      @user ||= @config.user || @config_from_file['galaxy.console.user'] || nil
    end

    def announcement_url
      @announcement_url ||= @config.announcement_url || @config_from_file['galaxy.console.announcement-url'] || `hostname`.strip
    end

    def host
      @host ||= @config.host || @config_from_file['galaxy.console.host'] || `hostname`.strip
    end

    def ping_interval
      @ping_interval ||= @config.ping_interval || @config_from_file['galaxy.console.ping-interval'] || 60
      @ping_interval = @ping_interval.to_i
    end
  
    def environment
      if @env
        @env
      elsif @config.environment
        @env = @config.environment
      elsif @config_from_file['galaxy.console.environment']
        @env = @config_from_file['galaxy.console.environment']
      elsif host =~ /^(?:\w+\.*)(\w+)\.ningops\.net$/
        @env = $1
      elsif host =~ /^(?:\w+\.)*(\w+)\.ninginc\.com$/
        @env = $1
      end
    end
      
  end
end
