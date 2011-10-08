require 'active_support/inflections'

class Hobson::Project::TestRun::Job::Tests

  include Enumerable

  attr_reader :job
  delegate :data, :to => :job

  def initialize job
    @job = job
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
    @other_tests ||= job.test_run.project.test_runs.map(&:jobs).flatten.reject{|other_job| other_job == job }.map(&:tests)
  end

  private

  def tests
    data.
      inject([]){ |tests, (key, value)| key =~ /^test:(.*):(.*)$/ and tests << $1; tests }.
      uniq.
      sort.
      map{|name| self[name] }
  end

  class Test

    attr_reader :tests, :name

    def initialize tests, name
      @tests, @name = tests, name
      self.status ||= "waiting"
    end

    %w{status result runtime est_runtime}.each do |attr|
      class_eval <<-RUBY, __FILE__, __LINE__
        def #{attr}
          tests.job["test:\#{name}:#{attr}"]
        end
        def #{attr}= value
          tests.job["test:\#{name}:#{attr}"] = value
        end
      RUBY
    end

    def <=> other
      name <=> other.name
    end

    def calculate_estimated_runtime!
      runtimes = tests.other_tests.map{|tests| tests[name].runtime }.compact
      self.est_runtime = runtimes.find_all(&:present?).inject(&:+).to_f / runtimes.size
    end

    def inspect
      "#<#{self.class} #{name}>"
    end
    alias_method :to_s, :inspect

  end

end

