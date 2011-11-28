class Hobson::Project::TestRun::Tests::Test

  attr_reader :tests, :name

  def initialize tests, name
    @tests, @name = tests, name
    self.status ||= "waiting"
  end

  %w{job status result runtime est_runtime}.each do |attr|
    class_eval <<-RUBY, __FILE__, __LINE__
      def #{attr}
        tests.test_run["test:\#{name}:#{attr}"]
      end
      def #{attr}= value
        tests.test_run["test:\#{name}:#{attr}"] = value
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

  def type
    case name
      when /.feature$/: 'feature'
      when /_spec.rb$/: 'spec'
      # when /_test.rb$/: :test_unit
      else
        :unknown
    end
  end

  def <=> other
    name <=> other.name
  end

  MINIMUM_ESTIMATED_RUNTIME = 0.1

  def calculate_estimated_runtime!
    self.est_runtime ||= begin
      runtimes = tests.other_tests.map{|tests| tests[name].runtime }.compact
      sum = runtimes.map(&:to_f).sum
      sum <= 0 ? MINIMUM_ESTIMATED_RUNTIME : sum / runtimes.size
    end
  end

  def inspect
    "#<#{self.class} "\
    "name:#{name.inspect} "\
    "est_runtime:#{est_runtime.inspect} "\
    "job:#{job.inspect} "\
    "status:#{status.inspect} "\
    "result:#{result.inspect} "\
    "runtime:#{runtime.inspect}>"
  end
  alias_method :to_s, :inspect

end
