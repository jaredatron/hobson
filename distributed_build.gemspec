# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "distributed_build/version"

Gem::Specification.new do |s|
  s.name        = "distributed_build"
  s.version     = DistributedBuild::VERSION
  s.authors     = ["Jared"]
  s.email       = ["jared@deadlyicon.com"]
  s.homepage    = "http://github.com/deadlyicon/distributed_build"
  s.summary     = %q{run your build in parallel across multiple machine}
  s.description = %q{run your build in parallel across multiple machine}

  s.rubyforge_project = "distributed_build"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency "parallel"
  s.add_development_dependency "logging"
end
