module Galaxy
  module Commands
    class ReapCommand < Command
      register_command "reap"
      changes_console_state
      
      def execute agents
        agents.each do |agent|
          puts "Reaping #{agent.host}"
          @options[:console].reap agent.host
        end
      end

      def self.help
        return <<-HELP
        #{name}
        
        Delete stale announcements (from the console) for the selected hosts, without affecting agents
        HELP
      end
    end
  end
end
