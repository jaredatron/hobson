require 'benchmark'

class Hobson::RedisHash

  def initialize redis, key
    @redis, @key, = redis, key
    reload!
  end

  attr_reader :redis, :key
  delegate :keys, :to => :cache

  def get field
    value = @redis.hget(@key, field.to_s)
    value ? deserialize(value) : nil
  end

  def set field, value
    @redis.hset(@key, field.to_s, serialize(value))
  end

  def [] field
    cache[field.to_s]
  end

  def []= field, value
    cache[field.to_s] = value
    set(field, value)
  end

  def delete key
    redis.hdel(@key, key)
    @cache.delete(key) if @cache
  end

  def cache
    @cache ||= @redis.hgetall(@key).inject({}) do |cache,(field,value)|
      cache.update field => deserialize(value)
    end
  end

  def to_hash
    cache.clone
  end

  def reload!
    @cache = nil
  end

  def inspect
    "#<#{self.class} #{key} #{cache.inspect}>"
  end
  alias_method :to_s, :inspect

  private

  def serialize value
    Marshal.dump(value)
  end

  def deserialize value
    Marshal.load(value)
  end

end
