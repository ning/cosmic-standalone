require 'ostruct'
require 'galaxy/db'

module Galaxy
  module Commands
    class EditDeploymentCommand < Command
      register_command "edit-deployment"
      
      def initialize args, options
        super
        if args.empty?
          raise CommandLineError.new("Expecting one or more properties to edit in key=value format")
        end
        args.each do |property|
          key, value = property.split('=', 2)
          case key
          when 'autostart'
            case value
            when 'true'
              @set_auto_start = true
            when 'false'
              @set_auto_start = false
            else
              raise CommandLineError.new("Unknown value for autostart property: #{value}")
            end
          else
            raise CommandLineError.new("Unknown property: #{key}")
          end
        end
        options[:data_dir] ||= options[:config_from_file]['galaxy.agent.data-dir']
        unless options[:help_requested]
          unless options[:data_dir]
            raise CommandLineError.new("Unable to determine agent data directory")
          end
          @db = Galaxy::DB.new(options[:data_dir])
        end
      end
      
      def select_agents filter
        @deployment_number = @db['deployment']
        serialized_deployment_descriptor = @db[@deployment_number]
        agent = YAML.load(serialized_deployment_descriptor) || OpenStruct.new
        # Ensure autostart=true for pre-2.5 deployments
        if agent.auto_start.nil?
          agent.auto_start = true
        end
        # TODO - determine running state
        [agent]
      end
      
      def execute agents
        agent = agents[0]
        agent.auto_start = @set_auto_start unless @set_auto_start.nil?
        @db[@deployment_number] = YAML.dump(agent)
        
        report.start
        report.record_result agent
        report.finish
      end

      def report_class
        Galaxy::Client::LocalSoftwareDeploymentReport
      end
      
      def self.help
        return <<-HELP
        #{name} { autostart={true|false} }
        
        Sets properties for the current software deployment for the local agent
        
        This command must be run from the host containing the target agent. The path to the agent's data directory must be provided,
        either via the 'galaxy.agent.data-dir' configuration file property, or via the '-d' / '--data' command-line argument, like so:
        
          % galaxy -d /path/to/agent/data/dir edit-deployment property=value ...
          
        Available properties:
        
          autostart:
          
              Controls whether galaxy-agent starts the core automatically when galaxy-agent starts.
          
              When 'true', galaxy-agent will automatically start the core (but only if the core was running when galaxy-agent last stopped).
              When 'false', galaxy-agent will not automatically start the core.
        HELP
      end
    end
  end
end
