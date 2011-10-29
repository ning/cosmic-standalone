require "openssl"
require "soap/wsdlDriver"

module F5
  class IControl
    attr_reader :hostname, :username, :password, :directory
    attr_accessor :wsdls, :endpoint, :interfaces

    def initialize hostname, username, password, wsdls = []
      @hostname = hostname
      @username = username
      @password = password
      @directory = File.dirname(__FILE__) + '/wsdl/'
      @wsdls = wsdls
      @endpoint = '/iControl/iControlPortal.cgi'
      @interfaces = {}
    end

    def get_interfaces
      @wsdls.each do |wsdl|
        wsdl = wsdl.sub(/.wsdl$/, '')
        wsdl_path = @directory + '/' + wsdl + '.wsdl'

        if File.exists? wsdl_path
          @interfaces[wsdl] = SOAP::WSDLDriverFactory.new('file://' + wsdl_path).create_rpc_driver
          @interfaces[wsdl].options['protocol.http.ssl_config.verify_mode'] = OpenSSL::SSL::VERIFY_NONE
          @interfaces[wsdl].options['protocol.http.ssl_config.verify_callback'] = lambda{ |arg1, arg2| true }


          @interfaces[wsdl].options['protocol.http.basic_auth']  << ['https://' + @hostname + '/' + @endpoint, @username, @password]
          @interfaces[wsdl].endpoint_url = 'https://' + @hostname + '/' + @endpoint
        end
      end

      @interfaces
    end

    def get_all_interfaces
      @wsdls = self.available_wsdls
      self.get_interfaces
    end

    def available_interfaces
      @interfaces.keys.sort
    end

    def available_wsdls
      Dir.entries(@directory).delete_if {|file| !file.end_with? '.wsdl'}.map {|file| file.gsub(/\.wsdl$/, '')}.sort
    end
  end
end
