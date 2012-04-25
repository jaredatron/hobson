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
    return if aborted?

    started_building!

    logger.info "checking out #{sha}"
    workspace.checkout! sha

    logger.info "bundle installing"
    workspace.bundle_install!

    logger.info "detecting tests"
    tests.detect!

    raise "no tests found" if tests.size < 1

    logger.info "balancing tests"
    tests.balance!

    tests_without_a_job = tests.find_all{|test| test.job.nil?}
    if tests_without_a_job.present?
      raise "FAILED to balance tests!\nThe following tests have no job: #{tests_without_a_job.map(&:name)*' '}"
    end

    raise "no jobs to schedule" if tests.number_of_jobs < 1

    logger.info "enqueuing #{tests.number_of_jobs} jobs to run #{tests.length} tests"
    # jobs.each(&:enqueue!)
    (0...tests.number_of_jobs).map{|index|
      job = Job.new(self, index)
      job.created!
      job.enqueue!
    }

    enqueued_jobs! # done

    # TODO upload Hobson.temp_logfile as a test_run artifact
  end

end
