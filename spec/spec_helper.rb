require 'hobson'
require 'resque_unit'
Fog.mock!

SPEC_ROOT = Pathname.new(File.expand_path('..', __FILE__))
ROOT      = SPEC_ROOT + '..'
TMP       = ROOT + 'tmp'

DEFAULT_CONFIG = {
  :redis => {
    :host      => "127.0.0.1",
    :port      => 6379,
    :db        => 0,
    :namespace => "hobson",
  },
  :storage => {
    :provider              => "aws",
    :aws_secret_access_key => "x",
    :aws_access_key_id     => "x",
    :directory             => "test_bucket",
  },
}

TMP.rmtree if TMP.exist?

SPEC_ROOT.join('support').children.each{ |support| require support.to_s }

# ClientWorkingDirectory.path.rmtree if ClientWorkingDirectory.path.exist?
# WorkerWorkingDirectory.path.rmtree if WorkerWorkingDirectory.path.exist?

RSpec.configure do |config|
  # config.mock_with :rr
  config.color_enabled = true
  config.include Test::Unit::Assertions
  config.include ResqueUnit::Assertions
  config.include GitSupport
  config.extend Contexts

  config.before :each do
    ENV['HOBSON_CONFIG'] = nil
    ENV['HOBSON_ROOT']   = nil

    Hobson.reset_logger!
    Resque.reset!
    Redis.new.flushall
    Hobson.instance_variables.each{|i| Hobson.send :remove_instance_variable, i }
    Hobson.instance_variables.should == []
  end

end
