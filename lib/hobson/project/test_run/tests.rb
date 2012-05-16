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

  def types
    tests.map(&:type).uniq
  end

  def [] test_id
    tests.find{ |test| test.id == test_id }
  end

  def add test_id
    tests << Test.new(test_run, test_id) if self[test_id].nil?
    self
  end

  # scans the workspace
  def detect!
    detect_specs!     if test_run.workspace.root.join('spec').exist?
    detect_scenarios! if test_run.workspace.root.join('features').exist?
    self
  end

  # scans the workspace for spec files and uses their relative path as their name
  def detect_specs!
    Dir[test_run.workspace.root.join('spec/**/*_spec.rb')].flatten. map{ |spec|
      name = Pathname.new(spec).relative_path_from(test_run.workspace.root).to_s
      add("spec:#{name}")
    }
  end

  # executes a cucumber command to list all scenarios by name
  def detect_scenarios!
    test_run.workspace.execute %W[
      cucumber --quiet --dry-run --no-profile
      --require #{Hobson.lib.join('hobson/formatters/scenarios.rb')}
      --format Hobson::Formatters::Scenarios --out hobson_scenarios_list
    ]*' '
    scenarios = test_run.workspace.root.join('hobson_scenarios_list').read.split("\n")
    # some crazy duplicate detection code i copied from the interwebz
    dups = scenarios.inject({}) {|h,v| h[v]=h[v].to_i+1; h}.reject{|k,v| v==1}.keys
    raise "Hobson cannot handle duplicate scenario names\nPlease correct these: #{dups.inspect}" if dups.present?
    scenarios.each{|name| add "scenario:#{name}"}
  end

  Group = Struct.new(:tests, :runtime, :jobs)
  def balance_for! number_of_jobs
    test_run.logger.debug "balancing #{length} tests for #{number_of_jobs} jobs"
    raise "number of jobs must be an integer" unless number_of_jobs.is_a? Integer
    raise "there must be at least 1 job" if number_of_jobs < 1

    # calculate estimates runtimes
    each(&:calculate_estimated_runtime!)

    # celing the number of jobs at the number of tests we have to run
    number_of_jobs = self.size if number_of_jobs > self.size

    # one job is easy
    return each{|test| test.job = 0 } if number_of_jobs == 1

    jobs = (0...number_of_jobs).map{|index| index}

    # group tests by their type
    groups = group_by(&:type).inject({}){ |hash, (type, tests)| hash.update(type => Group.new(tests)) }

    # calculate the total runtime of each group
    groups.each{|type, group|
      runtime = group.tests.map(&:est_runtime).inject(&:+)
      group.runtime = runtime
    }

    # calculate the total runtime of the entire test set
    total_runtime = groups.values.map(&:runtime).inject(&:+)

    # calculate the number of jobs for each group
    groups.each{|type, group|
      group.jobs = []
      jobs_for_this_group = ((group.runtime / total_runtime) * number_of_jobs).to_i
      jobs_for_this_group = 1 if jobs_for_this_group < 1
      jobs_for_this_group.times{ group.jobs << jobs.shift }
    }

    # assign unalocated jobs any group that could use them
    while jobs.present?
      thirsty_group = groups.values \
        # find all the jobs that could break up their tests more
        .find_all{|group| group.jobs.size < group.tests.size } \
        # find the thirstiest of the bunch
        .sort_by{|group| group.jobs.size }.first
      break if thirsty_group.nil?
      thirsty_group.jobs << jobs.shift
    end

    # balance tests across their given number of jobs
    groups.each{|type, group|
      # create a hash of job_index => total_est_runtime
      jobs_for_this_group = group.jobs.inject({}){|hash, job_index|
        hash.update job_index => 0.0
      }

      # for each test, biggest to smallest, add them to the lightest loaded worker
      group.tests.sort_by(&:est_runtime).reverse.each{|test|
        # sort the jobs by est_runtime and index number and take the smallest-sized & lowest-indexed one
        job_index = jobs_for_this_group.sort_by{|job,est_runtime| [est_runtime, job]}.first.first
        jobs_for_this_group[job_index] += test.est_runtime # add this jobs runtime
        test.job = job_index # assign this test to that job
      }
    }
  end

  def balance! runtime_target=5.minutes
    raise "there are no tests" unless length > 0

    each(&:calculate_estimated_runtime!)

    jobs = group_by(&:type).map{|group, tests|
      Hobson::StonePacker.pack(tests, runtime_target, &:est_runtime)
    }.inject(&:+)

    jobs.each_with_index{|job, index|
      job.each{|test| test.job = index}
    }
  end

  def number_of_jobs
    map(&:job).compact.uniq.size
  end

  def inspect
    "#<#{self.class} #{tests.inspect}>"
  end
  alias_method :to_s, :inspect

  # loops though all the keys in the test_run hash finding tests by regexp
  # and creating Test instances for them
  def reload!
    @tests = []
    test_run.data.each{ |(key, value)|
      key =~ /^test:(.+?):(.+?):(.+?)$/ and add("#{$1}:#{$2}")
    }
  end

  def to_a
    tests.clone
  end

  private

  def tests
    @tests or reload!
    @tests
  end

  delegate :each, :inspect, :to_s, :==, '<=>', :size, :length, :count, :to => :tests
  def method_missing method, *args, &block
    tests.send method, *args, &block
  end
end

