require 'ostruct'
require 'logger'
require 'galaxy/filter'
require 'galaxy/transport'
require 'galaxy/announcements'

module Galaxy

  class Console
    attr_reader :db

    def self.locate url
      Galaxy::Transport.locate url
    end

    def initialize drb_url, http_url, log, log_level, ping_interval
      @log =
          case log
          when "SYSLOG"
            Galaxy::HostUtils.logger "galaxy-console"
          when "STDOUT"
            Logger.new STDOUT
          when "STDERR"
            Logger.new STDERR
          else
            Logger.new log
          end
      @log.level = log_level
      @drb_url = drb_url
      @ping_interval = ping_interval
      @db = {}
      @mutex = Mutex.new

      # announcements
      @log.info "Listening for HTTP announcements on '#{http_url}'"
      @announcements = HTTPAnnouncementReceiver.new http_url, lambda{|a| http_announce(a)}, @log

      Thread.new do
        loop do
          begin
            cutoff = Time.new
            sleep @ping_interval
            ping cutoff
          rescue Exception => e
            @log.warn "Uncaught exception in agent ping thread: #{e}"
            @log.warn e.backtrace
          end
        end
      end
    end

    def ping cutoff
      @mutex.synchronize do
        @db.each_pair do |host, entry|
          if entry.agent_status != "offline" and entry.timestamp < cutoff
            @log.warn "#{host} failed to announce; marking as offline"
            entry.agent_status = "offline"
            entry.status = "unknown"
          end
        end
      end
    end

    # Remote API
    def reap host
      @mutex.synchronize do
        @db.delete host
      end
    end

    # Remote API
    def agents filters = { :set => :all }
      filter = Galaxy::Filter.new filters
      @mutex.synchronize do
        @db.values.select(&filter)
      end
    end

    # this function is called as a callback from http post server. We could just use the announce function as the
    # callback, but using this function allows us to add in different stats for post announcements.
    def http_announce announcement
      announce announcement
    end

    # Remote API
    def announce announcement
      begin
        host = announcement.host
        @log.debug "Received announcement from #{host}"
        @mutex.synchronize do
          if @db.has_key?(host)
            @log.info "#{host} is now online again" unless @db[host].agent_status != "offline"
            if @db[host].status != announcement.status
              @log.info "#{host} core state changed: #{@db[host].status} --> #{announcement.status}"
            end
          else
            @log.info "Discovered new agent: #{host} [#{announcement.inspect}]"
          end

          @db[host] = announcement
          @db[host].timestamp = Time.now
          @db[host].agent_status = 'online'
        end
      rescue RuntimeError => e
        @log.warn "Error receiving announcement: #{e}"
      end
    end


    # Remote API
    def log msg
      @log.info msg
    end

    def Console.start args
      host = args[:host] || "localhost"
      drb_url = args[:url] || "druby://" + host     # DRB transport
      drb_url += ":4440" unless drb_url.match ":[0-9]+$"

      http_url = args[:announcement_url] || "localhost"    # http announcements
      http_url = "#{http_url}:4442" unless http_url.match ":[0-9]+$"

      console = Console.new drb_url, http_url,
          args[:log] || "STDOUT",
          args[:log_level] || Logger::INFO,
          args[:ping_interval] || 5

      Galaxy::Transport.publish drb_url, console   # DRB transport
      console
    end

    def shutdown
      Galaxy::Transport.unpublish @drb_url
      @announcements.shutdown
    end

    def join
      Galaxy::Transport.join @drb_url
    end

  end
end
