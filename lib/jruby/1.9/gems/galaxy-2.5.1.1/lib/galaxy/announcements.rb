require 'webrick'
require 'net/http'
require 'uri'
require 'yaml'
require 'ostruct'
require 'logger'


module Galaxy

  class HTTPAnnouncementReceiver
#    DEFAULT_SERVER_LOG = "announcements_server.log"
#    DEFAULT_ACCESS_LOG = "announcements_access.log"

    def initialize(url, callback=nil, log=Logger.new(STDOUT))

      @log = log    # console log for info about starting /stopping the announcements server

      # WEBrick logs server info and, separately, access info. We'll ignore the access log, but may want it later.
      # Here's how:
      #      server_logfile = log_dir ? File.join(log_dir, DEFAULT_SERVER_LOG) : DEFAULT_SERVER_LOG
      #      access_logfile = log_dir ? File.join(log_dir, DEFAULT_ACCESS_LOG) : DEFAULT_ACCESS_LOG
      #        server_log = WEBrick::Log.new(server_logfile, WEBrick::Log::DEBUG)
      #        access_log_stream = File.open(access_logfile, 'w')
      #        access_log = [[ access_log_stream, WEBrick::AccessLog::COMBINED_LOG_FORMAT ]]

      # create server
      begin
        # read the port from the url string. Ignore the url. The announcement server 'publishes' on this machine
        port = get_port(url)
        # server logs => debug level, access logs => null
        null_log = WEBrick::Log.new('/dev/null', WEBrick::Log::ERROR)      
        null_access_log = [[null_log, WEBrick::AccessLog::COMBINED_LOG_FORMAT]]
        @server = WEBrick::HTTPServer.new(:Port => port, :Logger => @log, :AccessLog => null_access_log)
        #@server = WEBrick::HTTPServer.new(:Port => 4442)                   # example: start server without logging
      rescue Exception => err
        msg = "Announcements (server-side) server initialization error: #{err}"
        @log.error msg
        raise IOError, msg
      end


      #puts "Starting Announcement server on port #{@server[:Port]}"
      @server.mount "/status", AnnouncementStatus
      @server.mount "/", ReceiveAnnouncement, callback

      #trap "INT" do
      #  @server.shutdown
      #end

      # start server
      @thread = Thread.new do
        begin
          @log.debug "Starting announcement server"
          @server.start
        rescue Exception => err
          msg = "Announcements (server-side) server start error: #{err}"
          @log.error msg
          raise msg
        end
      end
    end


    # parse the port from the given url string
    def get_port(url)
      begin
        last = url.count(':')
        raise "malformed url: '#{url}'." if last==0 || last>2
        port = url.split(':')[last].to_i
      rescue Exception => err
        msg = "Problem parsing port for string '#{url}': error = #{err}"
        @log.error msg
        raise msg
      end
      port
    end


    def shutdown
      if @server
        @server.stop
        @server.shutdown
        @thread.join
        @server = @thread = nil
      end
    end
  end



  # POST handler that receives announcements and calls the callback function with the data payload
  class ReceiveAnnouncement < WEBrick::HTTPServlet::AbstractServlet
    ANNOUNCEMENT_RESPONSE_TEXT = "Announcement received."

    def initialize(server, cb)
      super(server)
      @callback = cb
    end

    def do_POST(request, response)
      vals = YAML::load(request.body)
      @callback.call(vals) if @callback

      response.status = 200
      response['Content-Type'] = 'text/plain; charset=utf-8'
      response['Connection'] = 'close'
      response.body = ANNOUNCEMENT_RESPONSE_TEXT
    end

  end

  # optional GET response for querying the server status
  class AnnouncementStatus < WEBrick::HTTPServlet::AbstractServlet

    # Process the request, return response
    def do_GET(request, response)
      body   = "<html><body>"
      body += "<h2>Announcement Status </h2> <br /><br />";
      time = Time.now
      body += time.strftime("%Y%m%d-%H:%M:%S") + sprintf(".%06d", time.usec)
      body += "</body></html>"

      response.status = 200
      response['Content-Type'] = "text/html"
      response['Connection'] = 'close'
      response.body = body
    end
  end


end

# Announcer sends announcements to the server
class HTTPAnnouncementSender

  def initialize(url, log = nil)
    # eg: 'http://encomium.ninginc.com:4440'
    @uri = URI.parse(url)
    @log = log
  end

  def announce(agent)
    begin
      # POST
      Net::HTTP.start(@uri.host, @uri.port) do |http|
        headers = {'Content-Type' => 'text/plain; charset=utf-8', 'Connection' => 'close'}
        put_data = agent.to_yaml
        start_time = Time.now
        response = http.send_request('POST', @uri.request_uri, put_data, headers)
        @log.debug "Announcement send response time for #{agent.host} = #{Time.now-start_time}" if @log
        #puts "Response = #{response.code} #{response.message}: #{response.body}"
        response.body
      end
    rescue Exception => e
      @log.warn "Client side error: #{e}" if @log
    end

  end

end




################################################################################################
#
# sample MAIN
#

# example callback for action upon receiving an announcement
def on_announcement(ann)
  puts "...received announcement: #{ann.inspect}"
end

# Initialize and POST to server
if $0 == __FILE__ then
  # start server
  url = 'http://encomium.ninginc.com:4440'
  Galaxy::HTTPAnnouncementReceiver.new(url, lambda{|a| on_announcement(a)})
  announcer = HTTPAnnouncementSender.new(url)

  # periodically, send stuff to it
  loop do
    begin

      announcer.announce(OpenStruct.new(:foo=>"bar", :rand => rand(100), :item => "eggs"))

      puts "server running..."
      sleep 15
    rescue Exception => err
      STDERR.puts "* #{err}"
      exit(1)
    end
  end
end
