require "hobson/version"
require 'redis'
require 'redis/slave'

require 'active_support'
require 'active_support/core_ext/array'
require 'active_support/core_ext/enumerable'
require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/object/try'
require 'active_support/inflections'

require 'pathname'
require 'resque'
require 'right_aws'

module Hobson

  DEFAULT_CONFIG = {
    :max_retries => 3,
  }.freeze

  extend self

  autoload :RedisSlave, 'hobson/redis_slave'
  autoload :RedisHash,  'hobson/redis_hash'
  autoload :Bundler,    'hobson/bundler'
  autoload :Landmarks,  'hobson/landmarks'
  autoload :Artifacts,  'hobson/artifacts'
  autoload :Project,    'hobson/project'
  autoload :Worker,     'hobson/worker'
  autoload :Server,     'hobson/server'
  autoload :CI,         'hobson/ci'

  def root
    @root ||= Pathname.new ENV['HOBSON_ROOT'] ||= Dir.pwd
  end

  def config_path
    @config_path ||= begin
      ENV['HOBSON_CONFIG'] ||= [root+'config/hobson.yml', root+'config.yml'].find{|path| File.exist? path.to_s }.to_s
      ENV['HOBSON_CONFIG'].present? ? Pathname.new(ENV['HOBSON_CONFIG']).to_s : nil
    end
  end

  def config
    @config ||= begin
      raise "unable to find config file in #{root}" unless config_path.present? && File.exists?(config_path)
      DEFAULT_CONFIG.merge(YAML.load_file(config_path))
    end
  end

  def lib
    @lib ||= Pathname.new File.expand_path('..', __FILE__)
  end

  def git_version
    @sha ||= `cd "#{Hobson.lib}" && git rev-parse HEAD`.chomp
  end

  def root_redis
    redis = self.redis || return
    while redis.is_a?(Redis::Namespace)
      redis = redis.instance_variable_get('@redis')
    end
    return redis
  end

  # set the root connection to redis preserving namespaces
  def root_redis= redis
    if self.redis.nil? || self.redis.is_a?(Redis) || self.redis.is_a?(Redis::Slave::Balancer)
      @redis = redis

    elsif self.redis.is_a?(Redis::Namespace)
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
      return nil unless config.present?
      options = config[:redis] || {}
      @redis = Redis.new(options)
      @redis = Redis::Namespace.new('Hobson', :redis => @redis)
      @redis = Redis::Namespace.new(options[:namespace], :redis => @redis) if options[:namespace]

      if $DEBUG || ENV['DEBUG']
        require 'benchmark'
        @redis = Class.new{
          instance_methods.each { |m| undef_method m unless m =~ /(^__|^send$|^object_id$)/ }
          def initialize redis
            @redis = redis
          end
          protected
          def method_missing(name, *args, &block)
            r = nil
            puts "REDIS: #{name.inspect}, #{args.inspect}, #{block_given?}"
            puts Benchmark.measure{ r = @redis.send(name, *args, &block) }
            return r
          end
        }.new(@redis)
      end

      @redis
    end
  end

  def resque
    @resque ||= begin
      return nil unless config.present?
      Resque.redis = Redis::Namespace.new(:resque, :redis => redis)
      Resque
    end
  end

  def s3
    @s3 ||= begin
      return nil unless
        config.present? &&
        config[:s3].present? &&
        config[:s3].has_key?(:access_key_id) &&
        config[:s3].has_key?(:secret_access_key)

      @s3 = RightAws::S3.new *config[:s3].values_at(:access_key_id, :secret_access_key)
      @s3.interface.logger= Hobson.logger
      @s3
    end
  end

  def s3_bucket
    @s3_bucket ||= begin
      return nil unless
        config.present? &&
        config[:s3].present? &&
        config[:s3].has_key?(:bucket)
      RightAws::S3::Bucket.new(s3, config[:s3][:bucket], false, 'public-read')
    end
  end

end

require 'hobson/logger'
