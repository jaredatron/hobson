class Hobson::RedisHash

  def initialize redis, key
    @redis, @key, = redis, key
    reload!
  end

  delegate :keys,   :to => :cache

  def [] field
    cache[field.to_s]
  end

  def []= field, value
    cache[field.to_s] = value
    @redis.hset(@key, field.to_s, Marshal.dump(value))
  end

  def cache
    @cache ||= @redis.hgetall(@key).inject({}) do |cache,(field,value)|
      cache.update field => Marshal.load(value)
    end
  end

  def to_hash
    cache.clone
  end

  def reload!
    @cache = nil
  end

end
