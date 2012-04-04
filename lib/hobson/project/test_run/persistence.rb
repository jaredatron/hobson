class Hobson::Project::TestRun

  MAX_AGE = 172800 # 2 days

  delegate :redis, :to => :project

  def redis_hash
    @redis_hash ||= Hobson::RedisHash.new(redis, "TestRun:#{id}")
  end

  def save!
    project.redis.zadd(:test_runs, created_at.to_f, id)
    redis_hash.redis.expire(redis_hash.key, MAX_AGE)
    created!
  end

  def delete!
    project.redis.zrem(:test_runs, id)
    redis.del("TestRun:#{id}")
    true
  end

  def new_record?
    data.empty?
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
