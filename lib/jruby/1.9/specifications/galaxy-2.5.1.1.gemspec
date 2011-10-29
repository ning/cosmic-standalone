# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{galaxy}
  s.version = "2.5.1.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Ning, Inc."]
  s.date = %q{2011-09-02}
  s.email = %q{core-eng@ning.com}
  s.executables = ["galaxy-agent", "galaxy-console", "galaxy"]
  s.files = ["lib/galaxy/agent.rb", "lib/galaxy/agent_utils.rb", "lib/galaxy/announcements.rb", "lib/galaxy/client.rb", "lib/galaxy/command.rb", "lib/galaxy/commands/assign.rb", "lib/galaxy/commands/clear.rb", "lib/galaxy/commands/edit_deployment.rb", "lib/galaxy/commands/perform.rb", "lib/galaxy/commands/reap.rb", "lib/galaxy/commands/restart.rb", "lib/galaxy/commands/rollback.rb", "lib/galaxy/commands/show.rb", "lib/galaxy/commands/show_agent.rb", "lib/galaxy/commands/show_deployment.rb", "lib/galaxy/commands/ssh.rb", "lib/galaxy/commands/start.rb", "lib/galaxy/commands/stop.rb", "lib/galaxy/commands/update.rb", "lib/galaxy/commands/update_config.rb", "lib/galaxy/config.rb", "lib/galaxy/console.rb", "lib/galaxy/controller.rb", "lib/galaxy/daemon.rb", "lib/galaxy/db.rb", "lib/galaxy/deployer.rb", "lib/galaxy/fetcher.rb", "lib/galaxy/filter.rb", "lib/galaxy/host.rb", "lib/galaxy/log.rb", "lib/galaxy/parallelize.rb", "lib/galaxy/properties.rb", "lib/galaxy/report.rb", "lib/galaxy/repository.rb", "lib/galaxy/software.rb", "lib/galaxy/starter.rb", "lib/galaxy/temp.rb", "lib/galaxy/transport.rb", "lib/galaxy/version.rb", "lib/galaxy/versioning.rb", "bin/galaxy", "bin/galaxy-agent", "bin/galaxy-console"]
  s.homepage = %q{http://home.ninginc.com/display/ENG/Galaxy}
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.5.1}
  s.summary = %q{Galaxy is a lightweight software deployment and management tool used to manage the Java cores and Apache httpd instances that make up the Ning platform.}

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
