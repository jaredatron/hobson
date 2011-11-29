module Hobson::CI

  autoload :ProjectRef, 'hobson/ci/project_ref'

  extend self
  include Enumerable

  def data
    @data ||= Hobson::RedisHash.new(Hobson.redis, "TestRun:CI")
  end

end
