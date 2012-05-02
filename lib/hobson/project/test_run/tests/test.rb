class Hobson::Project::TestRun::Tests::Test

  attr_accessor :test_run, :id, :type, :name

  MAX_TRIES = 3

  def initialize test_run, id
    @test_run, @id = test_run, id
    @type, @name = id.scan(/^(.+?):(.+)$/).first
    self.created_at ||= Time.now
    self.tries ||= 0
  end

  %w{job est_runtime created_at started_at completed_at result tries}.each do |attr|
    class_eval <<-RUBY, __FILE__, __LINE__
      def #{attr}
        @#{attr} ||= test_run["test:\#{id}:#{attr}"]
      end
      def #{attr}= value
        @#{attr}   = test_run["test:\#{id}:#{attr}"] = value
      end
    RUBY
  end

  def min_max_runtime
    1.minute
  end

  def max_runtime
    [est_runtime * 2, min_max_runtime].max
  end

  %w{PASS FAIL PENDING HUNG}.each do |result|
    class_eval <<-RUBY, __FILE__, __LINE__
      def #{result.downcase}?
        result == "#{result}"
      end
      def #{result.downcase}!
        self.result = "#{result}"
      end
    RUBY
  end

  # overrides above general definition
  def fail!
    if needs_run?
      reset!
    else
      self.result = "FAIL"
    end
  end

  # overrides above general definition
  def hung!
    if needs_run?
      reset!
    else
      self.result = "HUNG"
      self.completed_at = Time.now
    end
  end

  def trying!
    self.tries += 1
    reset!
  end

  def reset!
    self.started_at &&= nil
    self.completed_at &&= nil
    self.result &&= nil
  end

  def needs_run?
    !pass? && !pending? && tries < MAX_TRIES
  end

  def running?
    started_at.present? && !complete?
  end

  def complete?
    completed_at.present?
  end

  def status
    complete? ? 'complete' :
    running?  ? 'running'  :
    'waiting'
  end

  def runtime
    (completed_at || Time.now) - started_at if started_at.present?
  end

  def <=> other
    name <=> other.name
  end

  MINIMUM_EST_RUNTIME = 10.seconds

  def calculate_estimated_runtime!
    self.est_runtime ||= test_run.project.test_runtimes[id].average || MINIMUM_EST_RUNTIME
  end

  def inspect
    "#<#{self.class} "\
    "type:#{type.to_s.inspect} "\
    "name:#{name.inspect} "\
    "est_runtime:#{est_runtime.inspect} "\
    "job:#{job.inspect} "\
    "status:#{status.inspect} "\
    "result:#{result.inspect} "\
    "runtime:#{runtime.inspect} "\
    "tries:#{tries.inspect}>"
  end
  alias_method :to_s, :inspect

end
