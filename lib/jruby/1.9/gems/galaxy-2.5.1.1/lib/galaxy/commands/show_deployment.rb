require 'ostruct'
require 'galaxy/db'

module Galaxy
  module Commands
    class ShowDeploymentCommand < Command
      register_command "show-deployment"
      
      def initialize args, options
        super
        @data_dir = options[:data_dir] || options[:config_from_file]['galaxy.agent.data-dir']
        unless options[:help_requested]
          unless @data_dir
            raise CommandLineError.new("Unable to determine agent data directory")
          end
        end
      end
      
      def select_agents filter
        unless File.directory?(@data_dir)
          raise "Unable to read agent database directory #{@data_dir}"
        end
        @db = Galaxy::DB.new(@data_dir)
        deployment_number = @db['deployment']
        serialized_deployment_descriptor = @db[deployment_number]
        if serialized_deployment_descriptor.nil?
          raise "No active deployment found for this agent"
        end
        agent = YAML.load(serialized_deployment_descriptor) || OpenStruct.new
        # Ensure autostart=true for pre-2.5 deployments
        if agent.auto_start.nil?
          agent.auto_start = true
        end
        # TODO - determine running state
        [agent]
      end
      
      def execute agents
        report.start
        report.record_result agents[0]
        report.finish
      end

      def report_class
        Galaxy::Client::LocalSoftwareDeploymentReport
      end
      
      def self.help
        return <<-HELP
        #{name}
        
        Show the current software deployment for an agent
        
        This command must be run from the host containing the target agent. The path to the agent's data directory must be provided,
        either via the 'galaxy.agent.data-dir' configuration file property, or via the '-d' / '--data' command-line argument, like so:
        
          % galaxy -d /path/to/agent/data/dir show-deployment
        HELP
      end
    end
  end
end
