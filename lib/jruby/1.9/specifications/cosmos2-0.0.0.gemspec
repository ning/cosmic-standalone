# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{cosmos2}
  s.version = "0.0.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = [%q{Thomas Dudziak}]
  s.date = %q{2011-10-28}
  s.description = %q{Library/tool for automating deployments}
  s.email = %q{thomas@ning.com}
  s.executables = [%q{cosmos2}]
  s.extra_rdoc_files = [%q{LICENSE.txt}, %q{README.md}]
  s.files = [%q{bin/cosmos2}, %q{LICENSE.txt}, %q{README.md}]
  s.homepage = %q{https://github.com/ning/cosmos2}
  s.licenses = [%q{ASL2}]
  s.require_paths = [%q{lib}]
  s.required_ruby_version = Gem::Requirement.new(">= 1.8.7")
  s.rubygems_version = %q{1.8.9}
  s.summary = %q{Library/tool for automating deployments}

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<yard>, ["~> 0.6.1"])
      s.add_runtime_dependency(%q<highline>, ["~> 1.6.2"])
      s.add_runtime_dependency(%q<net-ldap>, ["~> 0.2.2"])
    else
      s.add_dependency(%q<yard>, ["~> 0.6.1"])
      s.add_dependency(%q<highline>, ["~> 1.6.2"])
      s.add_dependency(%q<net-ldap>, ["~> 0.2.2"])
    end
  else
    s.add_dependency(%q<yard>, ["~> 0.6.1"])
    s.add_dependency(%q<highline>, ["~> 1.6.2"])
    s.add_dependency(%q<net-ldap>, ["~> 0.2.2"])
  end
end
