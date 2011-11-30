# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "hobson/version"

Gem::Specification.new do |s|
  s.name        = "hobson"
  s.version     = Hobson::VERSION
  s.authors     = ["Jared"]
  s.email       = ["jared@deadlyicon.com"]
  s.homepage    = "http://github.com/deadlyicon/hobson"
  s.summary     = %q{run your build in parallel across multiple machine}
  s.description = %q{run your build in parallel across multiple machine}

  s.rubyforge_project = "hobson"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency "ruby-debug"
  s.add_development_dependency "rake"
  s.add_development_dependency "shotgun"
  s.add_development_dependency "rspec"
  s.add_development_dependency "resque_unit"

  s.add_runtime_dependency "activesupport", "~> 3.0.10"
  s.add_runtime_dependency "i18n"
  s.add_runtime_dependency "redis-namespace", "~> 1"
  s.add_runtime_dependency "resque", "~> 1.19.0"
  s.add_runtime_dependency "daemons"
  s.add_runtime_dependency "right_aws"
  s.add_runtime_dependency "SystemTimer"
  s.add_runtime_dependency "childprocess"
  s.add_runtime_dependency "log4r"
  s.add_runtime_dependency "json"
  s.add_runtime_dependency "open4"
  s.add_runtime_dependency "uuid"
  s.add_runtime_dependency "thor", "~> 0.14.6"

  s.add_runtime_dependency "vegas"
  s.add_runtime_dependency "sinatra"
  s.add_runtime_dependency "haml"
  s.add_runtime_dependency "sass"

end
