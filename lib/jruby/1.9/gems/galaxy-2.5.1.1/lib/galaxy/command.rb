require 'galaxy/agent_utils'
require 'galaxy/parallelize'
require 'galaxy/report'

module Galaxy
  module Commands
    @@commands = { }
    
    def self.register_command command_name, command_class
      @@commands[command_name] = command_class
    end
    
    def self.[] command_name
      @@commands[command_name]
    end
    
    def self.each
      @@commands.keys.sort.each { |command| yield command }
    end
    
    class Command
      class << self
        attr_reader :name
      end

      attr_writer :report_class
      attr_writer :report

      def self.register_command name
        @name = name
        Galaxy::Commands.register_command name, self
      end
      
      def self.changes_agent_state
        define_method("changes_agent_state") do
          true
        end
      end
      
      def self.changes_console_state
        define_method("changes_console_state") do
          true
        end
      end
      
      def initialize args = [], options = {}
        @args = args
        @options = options
      end
      
      def changes_agent_state
        false
      end
      
      def changes_console_state
        false
      end
      
      def select_agents filter
        normalized_filter = normalize_filter(filter)
        @options[:console].agents(normalized_filter)
      end
      
      def normalize_filter filter
        filter = default_filter if filter.empty?
        filter
      end
      
      def default_filter
        { :set => :all }
      end
      
      def execute agents
        report.start
        agents.parallelize(@options[:thread_count]) do |agent|
          begin
            unless agent.agent_status == 'online'
              raise "Agent is not online"
            end
            Galaxy::AgentUtils::ping_agent(agent)
            result = execute_for_agent(agent)
            report.record_result result
          rescue TimeoutError
            $stderr.puts "Error: Timed out communicating with agent #{agent.host}"
          rescue Exception => e
            $stderr.puts "Error: #{agent.host}: #{e}"
          end
        end
        report.finish
      end
      
      def report
        @report ||= report_class.new
      end

      def report_class
        @report_class ||= Galaxy::Client::SoftwareDeploymentReport
      end
      
    end
  end
end

# load and register all commands
require 'galaxy/commands/assign'
require 'galaxy/commands/clear'
require 'galaxy/commands/edit_deployment'
require 'galaxy/commands/perform'
require 'galaxy/commands/reap'
require 'galaxy/commands/restart'
require 'galaxy/commands/rollback'
require 'galaxy/commands/show'
require 'galaxy/commands/show_agent'
require 'galaxy/commands/show_deployment'
require 'galaxy/commands/ssh'
require 'galaxy/commands/start'
require 'galaxy/commands/stop'
require 'galaxy/commands/update'
require 'galaxy/commands/update_config'
