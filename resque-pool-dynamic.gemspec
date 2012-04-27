# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "resque/pool/dynamic/version"

Gem::Specification.new do |s|
  s.name        = "resque-pool-dynamic"
  s.version     = Resque::Pool::Dynamic::VERSION
  s.authors     = ["Maciej Pasternacki"]
  s.email       = ["maciej@pasternacki.net"]
  s.homepage    = "https://github.com/mpasternacki/resque-pool-dynamic"
  s.summary     = "A dynamic manager for resque pool"
  s.description = <<EOF
A class to dynamically manage number of processes and status in the
resque pool with a command-line user interface to interacively manage
and supervise the worker pool.
EOF
  s.licenses = ['BSD']

  s.rubyforge_project = "resque-pool-dynamic"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency "yard"
  s.add_runtime_dependency "resque-pool"
  s.add_runtime_dependency "io-tail"
  s.add_runtime_dependency "rake"
  s.add_runtime_dependency "ripl"
end
