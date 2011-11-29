# this file is required by hobson.rb and by the resque-web bin

require 'hobson'

Resque.redis = Redis::Namespace.new(:resque, :redis => Hobson.redis)
