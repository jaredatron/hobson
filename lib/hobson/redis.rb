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
    if self.redis.nil? || self.redis.is_a?(Redis) || self.redis.is_a?(Redis::Slave::Balancer)
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

  def redis_slave
    @redis_slave ||= begin
      @redis_slave = Redis::Slave.new(:master => Hobson.config[:redis])
      @redis_slave.start!
      raise "Failed to start Redis Slave" unless @redis_slave.process.alive?
      puts "starting redis slave at #{@redis_slave.options[:slave].values_at(:host, :port).join(':')}"
      print "waiting for local redis-slave to catch up"
      missing, synced = [], false
      until synced
        begin
          missing = @redis_slave.balancer.master.keys - @redis_slave.balancer.slave.keys
        rescue Errno::ECONNREFUSED, RuntimeError
          next
        ensure
          synced = missing.count == 0
          print '.'
          sleep 1
        end
      end
      print "\n"
      @redis_slave
    end
  end

  def use_redis_slave!
    begin
      redis_slave.balancer.keys
    rescue Errno::ECONNREFUSED, RuntimeError
      puts "waiting for redis slave server to start and catch up..."
      sleep 1
      retry
    end
    Hobson.root_redis = redis_slave.balancer
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

end
