class Hobson::Project::TestRun::Tests

  autoload :Test, 'hobson/project/test_run/tests/test'

  include Enumerable

  attr_reader :test_run
  delegate :data, :to => :test_run

  def initialize test_run
    @test_run = test_run
  end

  delegate :each, :inspect, :to_s, :==, '<=>', :size, :length, :count, :to => :tests

  def push *names
    names.find_all(&:present?).each{|name| self[name] }
  end

  def << *tests
    tests.flatten.each{|test| push test }
  end

  def [] name
    Test.new(self, name.to_s)
  end

  def calculate_estimated_runtimes!
    tests.each(&:calculate_estimated_runtime!)
  end

  def other_tests
    @other_tests ||= (test_run.project.test_runs - test_run).map(&:tests)
  end

  private

  def tests
    data.
      inject([]){ |tests, (key, value)| key =~ /^test:(.*):(.*)$/ and tests << $1; tests }.
      uniq.
      sort.
      map{|name| self[name] }
  end

end

