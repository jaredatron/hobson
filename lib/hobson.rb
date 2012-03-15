require 'hobson/version'

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
require 'fog'

module Hobson

  DEFAULT_CONFIG = {
    :max_retries => 3,
  }.freeze

  extend self

  autoload :RedisSlave,   'hobson/redis_slave'
  autoload :RedisHash,    'hobson/redis_hash'
  autoload :Bundler,      'hobson/bundler'
  autoload :Landmarks,    'hobson/landmarks'
  autoload :Artifacts,    'hobson/artifacts'
  autoload :Project,      'hobson/project'
  autoload :Server,       'hobson/server'
  autoload :Worker,       'hobson/worker'
  autoload :CI,           'hobson/ci'

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
      raise "unable to find hobson config file in #{root}" unless config_path.present? && File.exists?(config_path)
      DEFAULT_CONFIG.merge(YAML.load_file(config_path))
    end
  end

  def lib
    @lib ||= Pathname.new File.expand_path('..', __FILE__)
  end

  def git_version
    @sha ||= `cd "#{Hobson.lib}" && git rev-parse HEAD`.chomp
  end

  def resque
    @resque ||= begin
      Resque.redis = Redis::Namespace.new(:resque, :redis => redis)
      Resque
    end
  end

  def files
    @files ||= begin
      raise "storage is not configured" unless config[:storage].present?
      config[:storage][:directory] ||= 'hobson'
      storage = Fog::Storage.new(config[:storage].reject{|k,v| k == :directory})
      directory = storage.directories.get(config[:storage][:directory])
      directory ||= begin
        storage.directories.create(:key => config[:storage][:directory], :public => true)
        storage.directories.get(config[:storage][:directory])
      end
      directory.files
    end
  end

  def projects project=nil
    project.present? ? Project[project] : redis.smembers(:projects).map{|p| Project[p] }
  end

end

require 'hobson/version'
require 'hobson/logger'
require 'hobson/redis'
