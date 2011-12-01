class Hobson::Project::TestRun

  delegate :redis, :to => :project

  def redis_hash
    @redis_hash ||= Hobson::RedisHash.new(redis, "TestRun:#{id}")
  end

  def delete!
    redis.del("TestRun:#{id}")
    true
  end

  delegate :[], :[]=, :keys, :to => :redis_hash

  def data
    redis_hash.to_hash
  end

  %w{sha}.each do |attribute|
    class_eval <<-RUBY, __FILE__, __LINE__
      def #{attribute}
        self[:#{attribute}]
      end

      def #{attribute}= value
        self[:#{attribute}] = value
      end
    RUBY
  end

end
