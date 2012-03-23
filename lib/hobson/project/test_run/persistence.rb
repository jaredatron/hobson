class Hobson::Project::TestRun

  MAX_AGE = 604800 # 7 days

  delegate :redis, :to => :project

  def redis_hash
    @redis_hash ||= Hobson::RedisHash.new(redis, "TestRun:#{id}")
  end

  def save!
    project.redis.sadd(:test_runs, id)
    redis_hash.redis.expire(redis_hash.key, MAX_AGE)
    created!
  end

  def delete!
    project.redis.srem(:test_runs, id)
    redis.del("TestRun:#{id}")
    true
  end

  delegate :[], :[]=, :keys, :to => :redis_hash

  def data
    redis_hash.to_hash
  end

  %w{sha requestor}.each do |attribute|
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
