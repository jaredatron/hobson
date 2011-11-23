class Hobson::Project::TestRun::Tests

  autoload :Test, 'hobson/project/test_run/tests/test'

  include Enumerable

  attr_reader :test_run

  def initialize test_run
    @test_run = test_run
  end

  delegate :each, :inspect, :to_s, :==, '<=>', :size, :length, :count, :to => :tests

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

  # TYPES.keys.each do |type|
  #   define_method type.pluralize do
  #     tests.find_all{|test| test.type == type}
  #   end
  # end

  # def by_type
  #   group_by(&:type)
  # end

  # scans the workspace
  def detect!
    TYPES.values.
      map{ |path| Dir[test_run.workspace.root.join(path)] }.
      flatten.
      map{ |path| Pathname.new(path).relative_path_from(test_run.workspace.root).to_s }.
      each{ |name| self[name].status = "waiting" }
    self
  end

  # MINIMUM_ESTIMATED_RUNTIME = 0.1

  Group = Struct.new(:tests, :runtime, :jobs)
  def balance_for! number_of_jobs
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

      group.tests.each{|test|
        job = jobs.sort_by(&:last).first.first # find the job with the smallest est runtime
        jobs[job] += test.est_runtime # add this jobs runtime
        test.job = job # assign this test to that job
      }
    }

    # grouped_percentages = grouped_runtimes.inject({}){ |hash, (type, runtime)|
    #   hash.update(type => (runtime / total_runtime) * number_of_jobs)
    # }


    # grouped_runtimes = grouped_tests.inject({}){ |hash, (type, tests)|
    #   runtime = tests.each(&:calculate_estimated_runtime!).map(&:est_runtime).find_all(&:present?).inject(&:+)
    #   hash.update(type => runtime || MINIMUM_ESTIMATED_RUNTIME)
    # }

    # total_runtime = grouped_runtimes.values.inject(&:+)

    # grouped_percentages = grouped_runtimes.inject({}){ |hash, (type, runtime)|
    #   hash.update(type => (runtime / total_runtime) * number_of_jobs)
    # }



    # NOTES ON TEST BALANCING
    # sum up the total expected execution time of each test type
    # devide up the number of workers purpotionally
    # then devide up the tests among those workers
  end

  def [] name
    Test.new(self, name.to_s)
  end

  private

  def tests
    test_run.data.
      inject([]){ |tests, (key, value)| key =~ /^test:(.*):(.*)$/ and tests << $1; tests }.
      uniq.
      sort.
      map{|name| self[name] }
  end
end

