# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "hobson/version"

Gem::Specification.new do |s|
  s.name        = "hobson-cli"
  s.version     = Hobson::VERSION
  s.authors     = ["Jared", "Kyle VanderBeek"]
  s.email       = ["jared@deadlyicon.com", "kylev@kylev.com"]
  s.homepage    = "http://github.com/deadlyicon/hobson"
  s.summary     = %q{Command line tools for launching Hobson builds}
  s.description = %q{Command line tools for launching Hobson builds}

  s.rubyforge_project = "hobson"

  s.files         = ["bin/hobson-cli"]
  s.executables   = ["hobson-cli"]

  s.add_runtime_dependency "thor"
  s.add_runtime_dependency "faraday" # Could we do this with stock http clients?
end
