# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{cinch}
  s.version = "1.1.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Lee Jarvis", "Dominik Honnef"]
  s.date = %q{2011-05-11}
  s.description = %q{A simple, friendly DSL for creating IRC bots}
  s.email = ["lee@jarvis.co", "dominikh@fork-bomb.org"]
  s.files = ["LICENSE", "README.md", "lib/cinch.rb", "lib/cinch/constants.rb", "lib/cinch/cache_manager.rb", "lib/cinch/channel.rb", "lib/cinch/user_manager.rb", "lib/cinch/message_queue.rb", "lib/cinch/bot.rb", "lib/cinch/irc.rb", "lib/cinch/ban.rb", "lib/cinch/syncable.rb", "lib/cinch/message.rb", "lib/cinch/channel_manager.rb", "lib/cinch/logger/zcbot_logger.rb", "lib/cinch/logger/null_logger.rb", "lib/cinch/logger/formatted_logger.rb", "lib/cinch/logger/logger.rb", "lib/cinch/isupport.rb", "lib/cinch/pattern.rb", "lib/cinch/user.rb", "lib/cinch/helpers.rb", "lib/cinch/callback.rb", "lib/cinch/rubyext/module.rb", "lib/cinch/rubyext/queue.rb", "lib/cinch/rubyext/infinity.rb", "lib/cinch/rubyext/string.rb", "lib/cinch/mask.rb", "lib/cinch/plugin.rb", "lib/cinch/exceptions.rb", "lib/cinch/mode_parser.rb", "examples/plugins/msg.rb", "examples/plugins/memo.rb", "examples/plugins/urban_dict.rb", "examples/plugins/last_nick.rb", "examples/plugins/join_part.rb", "examples/plugins/lambdas.rb", "examples/plugins/timer.rb", "examples/plugins/url_shorten.rb", "examples/plugins/multiple_matches.rb", "examples/plugins/hello.rb", "examples/plugins/own_events.rb", "examples/plugins/seen.rb", "examples/plugins/custom_prefix.rb", "examples/plugins/google.rb", "examples/plugins/autovoice.rb", "examples/plugins/hooks.rb", "examples/basic/msg.rb", "examples/basic/memo.rb", "examples/basic/urban_dict.rb", "examples/basic/join_part.rb", "examples/basic/url_shorten.rb", "examples/basic/hello.rb", "examples/basic/seen.rb", "examples/basic/google.rb", "examples/basic/autovoice.rb"]
  s.homepage = %q{http://rubydoc.info/github/cinchrb/cinch}
  s.require_paths = ["lib"]
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.1")
  s.rubygems_version = %q{1.5.1}
  s.summary = %q{An IRC Bot Building Framework}

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
