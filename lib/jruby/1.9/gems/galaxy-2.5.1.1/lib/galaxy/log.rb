module Galaxy
  module Log
    
    class LoggerIO < IO
      require 'strscan'
      
      def initialize log, level = :info
        @log = log
        @level = level
        @buffer = ""
      end

      def write str
        @buffer << str

        scanner = StringScanner.new(@buffer)
        
        while scanner.scan /([^\n]*)\n/
          line = scanner[1]
          case @level
            when :warn
              @log.warn line
            when :info
              @log.info line
            when :error
              @log.error line
          end
        end
        
        @buffer = scanner.rest
      end
    end
  end
end
    
if __FILE__ == $0
  def a
    b
  end
  
  def b
    raise "error"
  end
  
  require 'logger'
  
  log = Logger.new(STDERR)
  info = Galaxy::Log::LoggerIO.new log, :info
  warn = Galaxy::Log::LoggerIO.new log, :error
  $stdout = info
  $stderr = warn
  
  puts "hello world\nbye bye"
  
  a
end
