module Hobson

  def root_redis
    redis = self.redis or return
    while redis.is_a?(Redis::Namespace) || redis.is_a?(RedisBenchmarker)
      redis = redis.instance_variable_get('@redis')
    end
    return redis
  end

  # set the root connection to redis preserving namespaces
  def root_redis= redis
    if self.redis.nil? || self.redis.is_a?(Redis)
      @redis = redis

    elsif self.redis.is_a?(Redis::Namespace) || self.redis.is_a?(RedisBenchmarker)
      namespace = @redis
      until namespace.instance_variable_get('@redis').is_a?(Redis) ||
        namespace.instance_variable_get('@redis').is_a?(Redis::Slave::Balancer)
        namespace = namespace.instance_variable_get('@redis')
      end
      namespace.instance_variable_set('@redis', redis)

    else
      raise "unkown type of #{self.redis}"
    end
  end

  def redis
    @redis ||= begin
      options = config[:redis] || {}
      @redis = Redis.new(options)
      @redis = Redis::Namespace.new('Hobson', :redis => @redis)
      @redis = Redis::Namespace.new(options[:namespace], :redis => @redis) if options[:namespace]
      enable_redis_benchmarker! if $DEBUG || ENV['DEBUG']
      @redis
    end
  end

  require 'benchmark'
  class RedisBenchmarker
    instance_methods.each { |m| undef_method m unless m =~ /(^__|^send$|^object_id$)/ }

    def initialize redis
      @redis = redis
    end

    def is_a? object
      object == RedisBenchmarker || @redis.is_a?(object)
    end

    def method_missing(name, *args, &block)
      r = nil
      puts "REDIS: #{name.inspect}, #{args.inspect}, #{block_given?}"
      puts Benchmark.measure{ r = @redis.send(name, *args, &block) }
      return r
    end
  end

  def enable_redis_benchmarker!
    @redis = RedisBenchmarker.new(@redis) unless @redis.is_a? RedisBenchmarker
    @redis
  end

  def log_redis!
    root_redis.client.logger = Hobson.logger
  end

end
