require 'tempfile'
require 'syslog'
require 'logger'

module Galaxy

  module HostUtils

    def HostUtils.logger ident="galaxy"
      @logger ||= begin
        log = Syslog.open ident, Syslog::LOG_PID | Syslog::LOG_CONS , Syslog::LOG_LOCAL7
        class << log
          def warn *args
            warning *args
          end
          def error *args
            err *args
          end
          # set log levels from standard Logger levels
          def level=(val)
            case val    # Note that there are other log levels: LOG_EMERG, LOG_ALERT, LOG_CRIT, LOG_NOTICE
              when Logger::ERROR
                Syslog.mask = Syslog::LOG_UPTO(Syslog::LOG_ERR)
              when Logger::WARN
                Syslog.mask = Syslog::LOG_UPTO(Syslog::LOG_WARNING)
              when Logger::DEBUG
                Syslog.mask = Syslog::LOG_UPTO(Syslog::LOG_DEBUG)
              when Logger::INFO
                Syslog.mask = Syslog::LOG_UPTO(Syslog::LOG_INFO)
            end
          end
        end
        log
      end
    end

    # Returns the name of the user that invoked the command
    #
    # This implementation tries +who am i+, available on some unix platforms, to check the owner of the controlling terminal,
    # which preserves ownership across +su+ and +sudo+. Failing that, the environment is checked for a +USERNAME+ or +USER+ variable.
    # Finally, the system password database is consulted.
    def HostUtils.shell_user
      guesses = []
      guesses << `who am i 2> /dev/null`.split[0]
      guesses << ENV['USERNAME']
      guesses << ENV['USER']
      guesses << Etc.getpwuid(Process.uid).name
      guesses.first { |guess| not guess.nil? and not guess.empty? }
    end

    def HostUtils.avail_path
      @avail_path ||= begin
        directories = %w{/usr/local/var/galaxy /var/galaxy /var/tmp /tmp}
        directories.find { |dir| FileTest.writable? dir }
      end
    end

    def HostUtils.tar
      @tar ||= begin
        unless `which gtar` =~ /^no gtar/ || `which gtar`.length == 0
          "gtar"
        else
          "tar"
        end
      end
    end
    
    def HostUtils.switch_user user
      pwent = Etc::getpwnam(user)
      uid, gid = pwent.uid, pwent.gid
      if Process.gid != gid or Process.uid != uid
        Process::GID::change_privilege(gid)
        Process::initgroups(user, gid)
        Process::UID::change_privilege(uid)
      end
      if Process.gid != gid or Process.uid != uid
        abort("Error: unable to switch user to #{user}")
      end
    end
    
    class CommandFailedError < Exception
      def initialize command, exitstatus, output
        @command = command
        @exitstatus = exitstatus
        @output = output
      end
      
      def message
        "Command '#{@command}' exited with status code #{@exitstatus} and output: #{@output}"
      end
    end
    
    # An alternative to Kernel.system that invokes a command, raising an exception containing
    # the command's stdout and stderr if the command returns a status code other than 0
    def HostUtils.system command
      output = IO.popen("#{command} 2>&1") { |io| io.readlines }
      unless $?.success?
        raise CommandFailedError.new(command, $?.exitstatus, output)
      end
      output
    end
  end

end
