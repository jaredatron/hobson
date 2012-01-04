class Hobson::Project::TestRun

  def enqueue!
    Hobson.resque.enqueue(Hobson::Project::TestRun::Builder, project.name, id)
    enqueued_build!
  end

  # checkout the given sha
  # discover the tests that are needed to run
  # add a list of tests to the TestRun data
  # schedule N RunTests resque jobs for Y jobs (balancing is done in this step)
  def build!
    started_building!
    number_of_jobs = Resque.workers.length
    number_of_jobs = 2 if number_of_jobs < 2 # TODO move to project setting

    logger.info "checking out #{sha}"
    workspace.checkout! sha

    logger.info "detecting tests"
    tests.detect!

    logger.info "balancing tests"
    tests.balance_for! number_of_jobs

    logger.info "enqueuing #{number_of_jobs} jobs to run #{tests.length} tests"
    # jobs.each(&:enqueue!)
    (0...number_of_jobs).map{|index|
      job = Job.new(self, index)
      job.created!
      job.enqueue!
    }

    enqueued_jobs! # done

    # TODO upload Hobson.temp_logfile as a test_run artifact
  end

  def rerun_failed_tests!
    failed_tests = tests.find_all(&:fail?)
    job_index = jobs.size + 1
    failed_tests.each{|failed_test|
      failed_test.status = "waiting"
      failed_test.result = nil
      failed_test.runtime = nil
      failed_test.job = job_index
    }
    job = Job.new(self, job_index)
    job.created!
    job.enqueue!
  end

end
