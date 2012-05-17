class Hobson::Project::TestRun

  def enqueue!
    worker = fast_lane? ? Hobson::Project::TestRun::FastLaneBuilder : Hobson::Project::TestRun::Builder
    Hobson.resque.enqueue(worker, project.name, id)
    enqueued_build!
  end

  # checkout the given sha
  # discover the tests that are needed to run
  # add a list of tests to the TestRun data
  # schedule N RunTests resque jobs for Y jobs (balancing is done in this step)
  def build! number_of_jobs = Resque.workers.length
    return if aborted?

    started_building!

    logger.info "checking out #{sha}"
    workspace.checkout! sha

    logger.info "bundle installing"
    workspace.bundle_install!

    logger.info "detecting tests"
    tests.detect!

    raise "no tests found" if tests.empty?

    number_of_jobs = 1 if number_of_jobs < 1

    logger.info "balancing tests across #{number_of_jobs} jobs"
    # tests.balance!
    tests.balance_for!(number_of_jobs)

    tests_without_a_job = tests.find_all{|test| test.job.nil?}
    if tests_without_a_job.present?
      raise "FAILED to balance tests!\nThe following tests have no job: #{tests_without_a_job.map(&:name)*' '}"
    end

    raise "no jobs to schedule" if tests.number_of_jobs < 1

    logger.info "enqueuing #{tests.number_of_jobs} jobs to run #{tests.length} tests"

    if jobs.any?{|job| job.tests.empty? }
      raise "FAILED to balance tests!\nSome jobs do not have tests: #{jobs.map(&:tests).pretty_inspect}"
    end

    jobs.each{|job|
      job.created!
      job.enqueue!
    }

    # this is used to count down to the last worker
    self.redis.set("#{redis_key}:number_of_incomplete_jobs", number_of_jobs)

    enqueued_jobs! # done

  rescue Exception => e
    errored!
    logger.info %(Exception:\n#{e}\n#{e.backtrace.join("\n")})
    self['exception'] = e.to_s
    self['exception:class'] = e.class.to_s
    self['exception:message'] = e.message.to_s
    self['exception:backtrace'] = e.backtrace.join("\n")

    raise # raise so resque shows this as a failed job and you can retry it
    # TODO upload Hobson.temp_logfile as a test_run artifact
  end

  def rerun!
    if ci_project_ref.present?
      ci_project_ref.run_tests! sha
    else
      project.run_tests!(
        :sha => sha,
        :requestor => requestor,
        :requestor => requestor,
        :fast_lane => fast_lane
      )
    end
  end

end
