class Hobson::Project::TestRuntimes < Hobson::RedisHash

  MAX_REMEMBERED_RUNTIMES =  10

  attr_reader :project

  include Enumerable

  def initialize project
    @project = project
    super project.redis, :test_runtimes
  end

  # test_runtimes['foo_spec.rb'] # => #<Runtimes foo_spec.rb 76.0 [12, 100, 100, 100, 88.0, 56.0]>
  def [] test_id
    Runtimes.new(self, test_id)
  end

  def each &block
    keys.map{|test_id| self[test_id] }.each(&block)
  end

  class Runtimes

    attr_reader :test_runtimes, :test_id, :test_type, :test_name
    include Enumerable

    def initialize test_runtimes, test_id
      @test_runtimes, @test_id, @runtimes = test_runtimes, test_id
      @test_type, @test_name = test_id.scan(/^(.+?):(.+)$/).first
    end

    def to_a
      runtimes.clone
    end

    def each &block
      to_a.each(&block)
    end

    def average
      @average ||= runtimes.size > 0.0 ? runtimes.sum / runtimes.size : 0.0
    end
    alias_method :to_f, :average

    def to_i
      to_f.to_i
    end

    def << runtime
      @runtimes = nil; runtimes # reload runtimes
      @runtimes << runtime.to_f
      @runtimes = @runtimes.last(MAX_REMEMBERED_RUNTIMES)
      test_runtimes[test_id] = @runtimes
    end

    def inspect
      "#<#{self.class} #{test_type} #{test_name} #{average} #{runtimes.inspect}>"
    end
    alias_method :to_s, :inspect

    private

    def runtimes
      @runtimes ||= test_runtimes.get(test_id) || []
    end
  end

end
