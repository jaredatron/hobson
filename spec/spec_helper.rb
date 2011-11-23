require 'hobson'
require 'resque_unit'

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
  :s3 => {
    :secret_access_key => "INTENTIONALLY_LEFT_BLANK",
    :access_key_id     => "INTENTIONALLY_LEFT_BLANK",
    :bucket            => "INTENTIONALLY_LEFT_BLANK",
  },
}

SPEC_ROOT.join('support').children.each{ |support| require support.to_s }

# ClientWorkingDirectory.path.rmtree if ClientWorkingDirectory.path.exist?
# WorkerWorkingDirectory.path.rmtree if WorkerWorkingDirectory.path.exist?

RSpec.configure do |config|
  # config.mock_with :rr
  config.color_enabled = true
  config.include Test::Unit::Assertions
  config.include ResqueUnit::Assertions
  config.extend Contexts

  config.before :each do
    ENV['HOBSON_CONFIG'] = nil
    ENV['HOBSON_ROOT']   = nil
    Resque.reset!
    Redis.new.flushall
    Hobson.instance_variables.each{|i| Hobson.send :remove_instance_variable, i }
  end

end
