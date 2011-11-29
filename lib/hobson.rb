require 'active_support/core_ext/array'
require 'active_support/core_ext/enumerable'
require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/object/try'
require 'active_support/inflections'

require 'pathname'
require 'resque'
require 'right_aws'

module Hobson

  extend self

  autoload :RedisHash,    'hobson/redis_hash'
  autoload :Bundler,      'hobson/bundler'
  autoload :Landmarks,    'hobson/landmarks'
  autoload :Artifacts,    'hobson/artifacts'
  autoload :Project,      'hobson/project'
  autoload :Server,       'hobson/server'
  autoload :CI,           'hobson/ci'

  # become a resque-worker and handle hobson resque jobs
  def work!
    queues = (ENV['QUEUES'] || ENV['QUEUE'] || '*').to_s.split(',')

    worker = Resque::Worker.new(*queues)
    worker.verbose = ENV['LOGGING'] || ENV['VERBOSE']
    worker.very_verbose = ENV['VVERBOSE']

    puts "*** Waiting for builds #{worker}"

    worker.work(ENV['INTERVAL'] || 5) # interval, will block
  end

  def root
    @root ||= Pathname.new ENV['HOBSON_ROOT'] ||= Dir.pwd
  end

  def config_path
    @config_path ||= begin
      ENV['HOBSON_CONFIG'] ||= [root+'config/hobson.yml', root+'config.yml'].find{|path| File.exist? path.to_s }
      ENV['HOBSON_CONFIG'].present? ? Pathname.new(ENV['HOBSON_CONFIG']) : nil
    end
  end

  def config
    @config ||= begin
      raise "unable to find config file in #{root}" unless config_path.present? && File.exists?(config_path)
      YAML.load_file(config_path)
    end
  end

  def lib
    @lib ||= Pathname.new File.expand_path('..', __FILE__)
  end

  def redis
    @redis ||= begin
      return nil unless config.present?
      options = config[:redis] || {}
      @redis = Redis.new(options)
      @redis = Redis::Namespace.new('Hobson', :redis => @redis)
      @redis = Redis::Namespace.new(options[:namespace], :redis => @redis) if options[:namespace]
      @redis
    end
  end

  def resque
    @resque ||= begin
      Resque.redis = Redis::Namespace.new(:resque, :redis => redis)
      Resque
    end
  end

  def s3
    @s3 ||= begin
      return nil unless config.present?
      RightAws::S3.new *config[:s3].values_at(:access_key_id, :secret_access_key)
    end
  end

  def s3_bucket
    @s3_bucket ||= begin
      return nil unless config.present?
      s3.bucket(config[:s3][:bucket], true, 'public-read')
    end
  end

end

require 'hobson/logger'
