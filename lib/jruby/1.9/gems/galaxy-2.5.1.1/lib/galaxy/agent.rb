require 'fileutils'
require 'logger'
require 'ostruct'
require 'resolv'
require 'socket'
require 'stringio'
require 'yaml'

require 'galaxy/controller'
require 'galaxy/db'
require 'galaxy/deployer'
require 'galaxy/fetcher'
require 'galaxy/properties'
require 'galaxy/repository'
require 'galaxy/software'
require 'galaxy/starter'
require 'galaxy/transport'
require 'galaxy/version'
require 'galaxy/versioning'

module Galaxy

  class Agent
    attr_reader :host, :machine, :config, :locked
    attr_accessor :starter, :fetcher, :deployer, :db

    def initialize host, url, announcements_url, repository_base, deploy_dir,
        data_dir, binaries_base, log, log_level, announce_interval
      @drb_url = url
      @host = host
      @ip = Resolv.getaddress(@host)
      @log =
          case log
          when "SYSLOG"
            Galaxy::HostUtils.logger "galaxy-agent"
          when "STDOUT"
            Logger.new STDOUT
          when "STDERR"
            Logger.new STDERR
          else
            Logger.new log
          end

      @log.level = log_level

      @lock = OpenStruct.new(:owner => nil, :count => 0, :mutex => Mutex.new)

      # set up announcements
      @announcer = Galaxy::Transport.locate announcements_url, @log

      @announce_interval = announce_interval
      @prop_builder = Galaxy::Properties::Builder.new repository_base, @log
      @repository = Galaxy::Repository.new repository_base, @log
      @deployer = Galaxy::Deployer.new deploy_dir, @log
      @fetcher = Galaxy::Fetcher.new binaries_base, @log
      @starter = Galaxy::Starter.new @log
      @db = Galaxy::DB.new data_dir
      @repository_base = repository_base
      @binaries_base = binaries_base

      if RUBY_PLATFORM =~ /\w+-(\D+)/
        @os = $1
        @log.debug "Detected OS: #{@os}"
      end

      if File.exists? "/local/etc/globalzone"   # TODO - this should be passed in as an argument
        File.open "/local/etc/globalzone", "r" do |f|
          @machine = f.read.chomp
        end
      else
        @machine = Socket.gethostname
      end
      @log.debug "Detected machine: #{@machine}"

      @config = read_config current_deployment_number

      Galaxy::Transport.publish url, self
      announce
      restart_if_needed!

      @thread = Thread.start do
        loop do
          sleep @announce_interval
          announce
        end
      end
    end

    def lock
      @lock.mutex.synchronize do
        raise "Agent is locked performing another operation" unless @lock.owner.nil? || @lock.owner == Thread.current

        @lock.owner = Thread.current if @lock.owner.nil?

        @log.debug "Locking from #{caller[2]}" if @lock.count == 0
        @lock.count += 1
      end
    end

    def unlock
      @lock.mutex.synchronize do
        raise "Lock not owned by current thread" unless @lock.owner.nil? || @lock.owner == Thread.current
        @lock.count -= 1
        @lock.owner = nil if @lock.count == 0

        @log.debug "Unlocking from #{caller[2]}" if @lock.count == 0
      end
    end

    # Remote API
    def status
      OpenStruct.new(
          :host => @host,
            :ip => @ip,
            :url => @drb_url,
            :os => @os,
            :machine => @machine,
            :core_type => config.core_type,
            :config_path => config.config_path,
            :build => config.build,
            :status => @starter.status(config.core_base),
            :agent_status => 'online',
            :galaxy_version => Galaxy::Version
      )
    end

    def read_config deployment_number
      config = nil
      deployment_number = deployment_number.to_s
      data = @db[deployment_number]
      unless data.nil?
        begin
          config = YAML.load data
          unless config.is_a? OpenStruct
            config = nil
            raise "Expecting serialized OpenStruct"
          end
        rescue Exception => e
          @log.warn "Error reading deployment descriptor: #{@db.file_for(deployment_number)}: #{e}"
        end
      end
      config ||= OpenStruct.new
      # Ensure autostart=true for pre-2.5 deployments
      if config.auto_start.nil?
        config.auto_start = true
      end
      config
    end

    def write_config deployment_number, config
      deployment_number = deployment_number.to_s
      @db[deployment_number] = YAML.dump config
    end

    def current_deployment_number
      @db['deployment'] ||= "0"
      @db['deployment'].to_i
    end

    def current_deployment_number= deployment_number
      deployment_number = deployment_number.to_s
      @db['deployment'] = deployment_number
      @config = read_config deployment_number
    end

    # Remote API
    def announce
      @announcer.announce status
    rescue Exception => e
      @log.warn "Unable to communicate with console, #{e.message}"
      @log.warn e
    end

    # private
    def restart_if_needed!
      lock

      begin
        start! if config and config.state == "started" and config.auto_start
      ensure
        unlock
      end
    end

    # Remote API
    # command to become a specific core
    def become! requested_config_path, versioning_policy = Galaxy::Versioning::StrictVersioningPolicy # TODO - make this configurable w/ default
      lock

      begin
        requested_config = Galaxy::SoftwareConfiguration.new_from_config_path(requested_config_path)

        unless config.config_path.nil? or config.config_path.empty?
          current_config = Galaxy::SoftwareConfiguration.new_from_config_path(config.config_path) # TODO - this should already be tracked
          unless versioning_policy.assignment_allowed?(current_config, requested_config)
            raise "Versioning policy does not allow this version assignment"
          end
        end
        
        build_properties = @prop_builder.build(requested_config.config_path, "build.properties")
        type = build_properties['type']
        build = build_properties['build']
        os = build_properties['os']

        raise "Cannot determine binary type for #{requested_config.config_path}" if type.nil?
        raise "Cannot determine build number for #{requested_config.config_path}" if build.nil?

        if os and os != @os
          raise "Cannot assign #{requested_config.config_path} to #{@os} host (requires #{os})"
        end

        @log.info "Becoming #{type}-#{build} with #{requested_config.config_path}"

        stop!

        archive_path = @fetcher.fetch type, build

        new_deployment = current_deployment_number + 1
        core_base = deployer.deploy(new_deployment, archive_path, requested_config.config_path, @repository_base, @binaries_base)
        deployer.activate(new_deployment)
        FileUtils.rm(archive_path) if archive_path && File.exists?(archive_path)

        write_config new_deployment, OpenStruct.new(:core_type => type,
            :build => build,
            :core_base => core_base,
            :config_path => requested_config.config_path,
            :auto_start => true)

        self.current_deployment_number = new_deployment
        announce
        return status
      rescue => e
        @log.error "Unable to become #{requested_config_path}: #{e}"
        @log.error e.backtrace.join("\n\tfrom ")
        raise "Unable to become #{requested_config_path}: #{e}"
      ensure
        unlock
      end
    end

    # Remote API
    # Invoked by 'galaxy update-config <version>'
    def update_config! requested_version, versioning_policy = Galaxy::Versioning::StrictVersioningPolicy # TODO - make this configurable w/ default
      lock

      begin
        @log.info "Updating configuration to version #{requested_version}"

        if config.config_path.nil? or config.config_path.empty?
          raise "Cannot update configuration of unassigned host"
        end
        
        current_config = Galaxy::SoftwareConfiguration.new_from_config_path(config.config_path) # TODO - this should already be tracked
        requested_config = current_config.dup
        requested_config.version = requested_version
        
        unless versioning_policy.assignment_allowed?(current_config, requested_config)
          raise "Versioning policy does not allow this version assignment"
        end
        
        build_properties = @prop_builder.build(requested_config.config_path, "build.properties")
        type = build_properties['type']
        build = build_properties['build']

        raise "Cannot determine binary type for #{requested_config.config_path}" if type.nil?
        raise "Cannot determine build number for #{requested_config.config_path}" if build.nil?
        raise "Binary type differs (#{config.core_type} != #{type})" if config.core_type != type
        raise "Binary build number differs (#{config.build} != #{build})" if config.build != build

        @log.info "Updating configuration to #{requested_config.config_path}"

        controller = Galaxy::Controller.new config.core_base, config.config_path, @repository_base, @binaries_base, @log
        begin
          controller.perform! 'update-config', requested_config.config_path
        rescue Exception => e
          raise "Failed to update configuration for #{requested_config.config_path}: #{e}"
        end
        
        @config = OpenStruct.new(:core_type => type,
            :build => build,
            :core_base => config.core_base,
            :config_path => requested_config.config_path)
        
        write_config(current_deployment_number, @config)
        announce
        return status
      rescue => e
        @log.error "Unable to update configuration to version #{requested_version}: #{e}"
        @log.error e.backtrace.join("\n\tfrom ")
        raise "Unable to update configuration to version #{requested_version}: #{e}"
      ensure
        unlock
      end
    end

    # Remote API
    # rollback to the previous deployment
    def rollback!
      lock

      begin
        stop!

        if current_deployment_number > 0
          write_config current_deployment_number, OpenStruct.new()
          @core_base = @deployer.rollback current_deployment_number
          self.current_deployment_number = current_deployment_number - 1
        end

        announce
        return status
      rescue => e
        @log.error "Unable to rollback: #{e}"
        @log.error e.backtrace.join("\n\tfrom ")
        raise "Unable to rollback: #{e}"
      ensure
        unlock
      end
    end

    # Remote API
    # stop the current core
    def stop!
      lock

      begin
        if config.core_base
          @config.state = "stopped"
          write_config current_deployment_number, @config
          @log.debug "Stopping core"
          @starter.stop! config.core_base
        end

        announce
        return status
      ensure
        unlock
      end
    end

    # Remote API
    # Start the currently deployed core
    def start!
      lock

      begin
        if config.core_base
          @config.state = "started"
          write_config current_deployment_number, @config
          @log.debug "Starting core"
          @starter.start! config.core_base
        end

        announce
        return status
      ensure
        unlock
      end
    end

    # Remote API
    # Retart the currently deployed core
    def restart!
      lock

      begin
        if config.core_base
          @config.state = "started"
          write_config current_deployment_number, @config
          @log.debug "Restarting core"
          @starter.restart! config.core_base
        end

        announce
        return status
      ensure
        unlock
      end
    end

    # Remote API
    # Called by the galaxy 'clear' command
    def clear!
      lock

      begin
        stop!

        @log.debug "Clearing core"
        deployer.deactivate current_deployment_number
        self.current_deployment_number = current_deployment_number + 1

        announce
        return status
      ensure
        unlock
      end
    end

    # Remote API
    # Invoked by 'galaxy perform <command> [arguments]'
    def perform! command, args = ''
      lock

      begin
        @log.info "Performing command #{command} with arguments #{args}"
        controller = Galaxy::Controller.new config.core_base, config.config_path, @repository_base, @binaries_base, @log
        output = controller.perform! command, args
        announce
        return status, output
      rescue Exception => e
        @log.error "Unable to perform command #{command}: #{e}"
        @log.error e.backtrace.join("\n\tfrom ")
        raise "Unable to perform command #{command}: #{e}"
      ensure
        unlock
      end
    end

    # Stop the agent
    def shutdown
      @starter.stop! config.core_base if config
      @thread.kill
      Galaxy::Transport.unpublish @drb_url
    end

    # Wait for the agent to finish
    def join
      @thread.join
    end

    # args: host => IP/Name to uniquely identify this agent
    #     console => hostname of the console
    #     repository => base of url to repository
    #     binaries => base of url=l to binary repository
    #     deploy_dir => /path/to/deployment
    #     data_dir => /path/to/agent/data/storage
    #     log => /path/to/log || STDOUT || STDERR || SYSLOG
    #     url => url to listen on
    def Agent.start args
      host_url = args[:host] || "localhost"
      host_url = "druby://#{host_url}" unless host_url.match("^http://") || host_url.match("^druby://") # defaults to drb
      host_url = "#{host_url}:4441" unless host_url.match ":[0-9]+$"

      # default console to http/4442 unless specified
      console_url = args[:console] || "localhost"
      console_url = "http://" + console_url unless console_url.match("^http://") || console_url.match("^druby://")
      console_url += ":4442" unless console_url.match ":[0-9]+$"

      # need host as simple name without protocol or port
      host = args[:host] || "localhost"
      host = host.sub(/^http:\/\//, "")
      host = host.sub(/^druby:\/\//, "")
      host = host.sub(/:[0-9]+$/, "")

      agent = Agent.new host,
          host_url,
          console_url,
          args[:repository] || "/tmp/galaxy-agent-properties",
          args[:deploy_dir] || "/tmp/galaxy-agent-deploy",
          args[:data_dir] || "/tmp/galaxy-agent-data",
          args[:binaries] || "http://localhost:8000",
          args[:log] || "STDOUT",
          args[:log_level] || Logger::INFO,
          args[:announce_interval] || 60

      agent
    end

    private :initialize, :restart_if_needed!, :config

  end

end
