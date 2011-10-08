require 'rubygems'
require 'bundler/setup'
require File.expand_path('../lib/hobson', __FILE__)

run Hobson::Server
