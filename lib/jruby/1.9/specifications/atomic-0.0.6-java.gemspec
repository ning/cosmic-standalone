# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{atomic}
  s.version = "0.0.6"
  s.platform = %q{java}

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Charles Oliver Nutter", "MenTaLguY"]
  s.date = %q{2011-09-06}
  s.description = %q{An atomic reference implementation for JRuby and green or GIL-threaded impls}
  s.email = ["headius@headius.com", "mental@rydia.net"]
  s.files = ["lib/atomic.rb", "lib/atomic_reference.jar", "examples/atomic_example.rb", "examples/bench_atomic.rb", "test/test_atomic.rb", "README.txt", "atomic.gemspec", "Rakefile"]
  s.homepage = %q{http://github.com/headius/ruby-atomic}
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.5.1}
  s.summary = %q{An atomic reference implementation for JRuby and green or GIL-threaded impls}
  s.test_files = ["test/test_atomic.rb"]

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
