class Hobson::Project::TestRun::Tests::Test

  attr_accessor :test_run, :id, :type, :name

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


  %w{PASS FAIL PENDING}.each do |result|
    class_eval <<-RUBY, __FILE__, __LINE__
      def #{result.downcase}?
        result == "#{result}"
      end
    RUBY
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

  def waiting?
    started_at.blank?
  end

  def running?
    !waiting? && !complete?
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

  MINIMUM_EST_RUNTIME = 0.1

  def calculate_estimated_runtime!
    self.est_runtime ||= begin
      average_runtime = test_run.project.test_runtimes[id].average
      average_runtime = MINIMUM_EST_RUNTIME if average_runtime < MINIMUM_EST_RUNTIME
      average_runtime
    end
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
