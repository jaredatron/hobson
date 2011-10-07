require "distributed_build/version"

module DistributedBuild
  autoload :Master, 'distributed_build/master'
  autoload :Slave, 'distributed_build/slave'
end
