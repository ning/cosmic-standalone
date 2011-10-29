# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{jruby-openssl}
  s.version = "0.7.4"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = [%q{Ola Bini and JRuby contributors}]
  s.date = %q{2011-04-27}
  s.description = %q{JRuby-OpenSSL is an add-on gem for JRuby that emulates the Ruby OpenSSL native library.}
  s.email = %q{ola.bini@gmail.com}
  s.extra_rdoc_files = [%q{History.txt}, %q{Manifest.txt}, %q{README.txt}, %q{License.txt}]
  s.files = [%q{History.txt}, %q{Manifest.txt}, %q{README.txt}, %q{License.txt}]
  s.homepage = %q{http://jruby-extras.rubyforge.org/jruby-openssl}
  s.rdoc_options = [%q{--main}, %q{README.txt}]
  s.require_paths = [%q{lib}]
  s.rubyforge_project = %q{jruby-extras}
  s.rubygems_version = %q{1.8.9}
  s.summary = %q{OpenSSL add-on for JRuby}

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<bouncy-castle-java>, [">= 0"])
    else
      s.add_dependency(%q<bouncy-castle-java>, [">= 0"])
    end
  else
    s.add_dependency(%q<bouncy-castle-java>, [">= 0"])
  end
end
