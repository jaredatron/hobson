class Hobson::Project::TestRun

  def enqueue!
    Resque.enqueue(Hobson::BuildTestRun, project.name, id)
    enqueued_build!
  end

  # checkout the given sha
  # discover the tests that are needed to run
  # add a list of tests to the TestRun data
  # schedule N RunTests resque jobs for Y jobs (balancing is done in this step)
  def build!
    started_building!
    number_of_jobs = Resque.workers.length
    # TEMP while testing
    # number_of_jobs = 2

    logger.info "checking out #{sha}"
    workspace.checkout! sha

    logger.info "detecting tests"
    tests.detect!

    logger.info "enqueuing #{number_of_jobs} jobs to run #{tests.length} tests"

    tests_groups = tests.in_groups(number_of_jobs)

    # NOTES ON TEST BALANCING
    # sum up the total expected execution time of each test type
    # devide up the number of workers purpotionally
    # then devide up the tests among those workers

    (0..(number_of_jobs-1)).zip(tests_groups).map{|index, tests|
      job = Job.new(self, index)
      job.tests << tests
      job.tests.calculate_estimated_runtimes!
      job.enqueue!
    }

    enqueued_jobs!
  end

end
