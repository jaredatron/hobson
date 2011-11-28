module Hobson::CI

  autoload :ProjectRef, 'hobson/ci/project_ref'

  extend self
  include Enumerable

  def data
    @data ||= Hobson::RedisHash.new(Hobson.redis, "TestRun:CI")
  end

  # def watch origin, ref
  #   self["#{origin}::#{ref}"] ||= Ref.new(origin, new)
  # end

  # def each &block
  #   keys.each(&block)
  # end

  # def watch_ref ref
  # end



  # def method_missing method, *args, &block
  #   return redis_hash.send(method, *args, &block) if redis_hash.respond_to? method
  #   super
  # end

end
