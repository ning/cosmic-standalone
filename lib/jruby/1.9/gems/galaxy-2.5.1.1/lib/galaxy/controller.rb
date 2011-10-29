require 'logger'

module Galaxy
  
  class Controller
    
    def initialize core_base, config_path, repository_base, binaries_base, log
      @core_base = core_base
      @config_path = config_path
      @repository_base = repository_base
      @binaries_base = binaries_base
      script = File.join(@core_base, "bin", "control")
      if File.exists? script
        @script = File.executable?(script) ? script : "/bin/sh #{script}"
      else
        raise ControllerNotFoundException.new
      end
      @log = log
    end
    
    def perform! command, args = ''
      @log.info "Invoking control script: #{@script} #{command} #{args}"
      
      begin
        output = `#{@script} --base #{@core_base} --binaries #{@binaries_base} --config-path #{@config_path} --repository #{@repository_base} #{command} #{args} 2>&1`
      rescue Exception => e
        raise ControllerFailureException.new(command, e)
      end
      
      rv = $?.exitstatus
      
      case rv
      when 0
        output
      when 1
        raise CommandFailedException.new(command, output)
      when 2
        raise UnrecognizedCommandException.new(command, output)
      else
        raise UnrecognizedResponseCodeException.new(rv, command, output)
      end
    end
    
    class ControllerException < RuntimeError ; end
    
    class ControllerNotFoundException < ControllerException
      def initialize
        super "No control script available"
      end
    end
    
    class ControllerFailureException < ControllerException
      def initialize command, exception
        super "Unexpected exception executing command '#{command}': #{exception}"
      end
    end
    
    class CommandFailedException < ControllerException
      def initialize command, output
        super "Command failed: #{command}:\n#{output}"
      end
    end
    
    class UnrecognizedCommandException < ControllerException
      def initialize command, output
        super "Unrecognized command: #{command}\n#{output}"
      end
    end
    
    class UnrecognizedResponseCodeException < ControllerException
      def initialize code, command, output
        super "Unrecognized response code (#{code}) for command: #{command}\n#{output}"
      end
    end
    
  end
end
