class Hobson::Project::TestRun::Tests::Test

  attr_reader :tests, :name

  def initialize tests, name
    @tests, @name = tests, name
    self.status ||= "waiting"
  end

  %w{job status result runtime est_runtime}.each do |attr|
    class_eval <<-RUBY, __FILE__, __LINE__
      def #{attr}
        tests.job["test:\#{name}:#{attr}"]
      end
      def #{attr}= value
        tests.job["test:\#{name}:#{attr}"] = value
      end
    RUBY
  end

  def type
    case name
      when /.feature$/: :feature
      when /_spec.rb$/: :spec
      # when /_test.rb$/: :test_unit
      else
        :unknown
    end
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
