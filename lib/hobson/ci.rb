module Hobson::CI

  extend self

  autoload :ProjectRef, 'hobson/ci/project_ref'

  def redis
    @redis ||= Redis::Namespace.new(:ci, :redis => Hobson.redis)
  end

  def project_refs
    redis.smembers(:project_refs).map{|p| ProjectRef.find(p) }
  end

end
