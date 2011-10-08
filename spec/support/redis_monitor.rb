class RedisMonitor
  instance_methods.each { |m| undef_method m unless m =~ /^__/ }

  def initialize(redis)
    @redis = redis
    @method_calls = []
  end

  attr_reader :method_calls

  def method_missing(method, *args, &block)
    @method_calls << method
    @redis.__send__(method, *args, &block)
  end

end
