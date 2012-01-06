class Hobson::Project::TestRun::Tests

  autoload :Test, 'hobson/project/test_run/tests/test'

  include Enumerable

  attr_reader :test_run

  def initialize test_run
    @test_run = test_run
  end

  def calculate_estimated_runtimes!
    tests.each(&:calculate_estimated_runtime!)
  end

  def other_tests
    @other_tests ||= (test_run.project.test_runs - [test_run]).map(&:tests)
  end

  def types
    tests.map(&:type).uniq
  end

  TYPES = {
    'spec'    => 'spec/**/*_spec.rb',
    'feature' => 'features/**/*.feature',
  }

  # scans the workspace
  def detect!
    TYPES.values.
      map{ |path| Dir[test_run.workspace.root.join(path)] }.
      flatten.
      map{ |path| Pathname.new(path).relative_path_from(test_run.workspace.root).to_s }.
      each{ |name| self[name] }
    self
  end

  Group = Struct.new(:tests, :runtime, :jobs)
  def balance_for! number_of_jobs
    test_run.logger.debug "balancing #{length} tests for #{number_of_jobs} jobs"
    raise "number of jobs must be an integer" unless number_of_jobs.is_a? Integer
    raise "there must be at least 1 job" if number_of_jobs < 1

    # one job is easy
    return each{|test| test.job = 0 } if number_of_jobs == 1

    calculate_estimated_runtimes!

    jobs = (0...number_of_jobs).map{|index| index}

    # group tests by their type
    groups = group_by(&:type).inject({}){ |hash, (type, tests)| hash.update(type => Group.new(tests)) }

    # calculate the total runtime of each group
    groups.each{|type, group|
      runtime = group.tests.each(&:calculate_estimated_runtime!).map(&:est_runtime).inject(&:+)
      group.runtime = runtime
    }

    # calculate the total runtime of the entire test set
    total_runtime = groups.values.map(&:runtime).inject(&:+)

    # calculate the number of jobs for each group
    groups.each{|type, group|
      number_of_jobs = ((group.runtime / total_runtime) * number_of_jobs).to_i
      group.jobs = []
      number_of_jobs.times{ group.jobs << jobs.shift }
    }

    # assign unalocated jobs to the group with the least jobs
    groups.values.sort_by{|group| group.jobs.length}.first.jobs << jobs.shift while jobs.present?

    # balance tests across their given number of jobs
    groups.each{|type, group|
      jobs = {}
      group.jobs.each{|job| jobs[job] = 0}

      group.tests.sort_by(&:est_runtime).reverse.each{|test|
        job = jobs.sort_by(&:last).first.first # find the job with the smallest est runtime
        jobs[job] += test.est_runtime # add this jobs runtime
        test.job = job # assign this test to that job
      }
    }
  end

  def [] name
    test = Test.new(self, name.to_s)
    tests << test
    test
  end

  private

  def tests
    @tests or begin
      @tests = []
      test_run.data.
        inject([]){ |tests, (key, value)| key =~ /^test:(.*):(.*)$/ and tests << $1; tests }.
        uniq.
        sort.
        map{|name| self[name] }
    end
  end

  delegate :each, :inspect, :to_s, :==, '<=>', :size, :length, :count, :to => :tests
  def method_missing method, *args, &block
    tests.send method, *args, &block
  end
end

