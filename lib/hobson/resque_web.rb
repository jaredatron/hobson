require 'hobson'

Resque.redis = Redis::Namespace.new(:resque, :redis => Hobson.redis)
