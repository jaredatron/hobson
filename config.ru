require 'rubygems'
require 'bundler/setup'
require File.expand_path('../lib/hobson', __FILE__)

Hobson.log_to_stdout!
Hobson.use_redis_slave!
Hobson.log_redis!
run Hobson::Server
