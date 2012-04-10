require 'timeout'
require 'simplecov'


class Hobson::Project::TestRun::Job

  FINISH_TEST_RUN_LOCK = 'finish_test_run_lock'

  def enqueue!
    Hobson.resque.enqueue(Hobson::Project::TestRun::Runner, test_run.project.name, test_run.id, index)
    enqueued!
  end

  def lock_can_finish_test_run
    # test_run.redis
    result = false
    until result == true
      result = test_run.project.redis.setnx(FINISH_TEST_RUN_LOCK, 'lock')
      sleep 0.1
      #TODO: check for lock expiration
    end
  end

  def release_can_finish_test_run
    test_run.project.redis.del FINISH_TEST_RUN_LOCK
  end

  def can_finish_test_run?
    #make sure only one job is in here at any time:
    lock_can_finish_test_run
    begin
      # mark this job as ready for wrap up
      ready_to_finish_run!

      #This reload seems unnecessary, but the status is cached, and not cleared (except locally) on write.
      test_run.redis_hash.reload!
      test_run.jobs.all?(&:ready_to_finish_run?)
    ensure
      release_can_finish_test_run
    end
  end

  def run_tests!
    return if test_run.aborted?

    self['hostname'] = Timeout::timeout(5){ # try the S3 public hostname api
      `curl -s http://169.254.169.254/latest/meta-data/public-hostname`.chomp
    } rescue `hostname`.chomp

    unless abort?
      checking_out_code!
      workspace.checkout! test_run.sha
    end

    unless abort?
      preparing!
      workspace.prepare
      eval_hook :setup
    end

    unless abort?
      running_tests!
      test_runtimes = test_run.project.test_runtimes
      while (tests = test_needing_to_be_run).present?
        break if abort?
        eval_hook :before_running_tests, :tests => tests
        break if abort?
        tests.each(&:trying!)
        logger.debug "running tests: #{tests.map(&:id).inspect}"
        workspace.run_tests(tests){ |type, name, state, occured_at, result|
          test = tests.find{|test| test.id == "#{type}:#{name}" }
          test or raise "status update for unknown test #{name.inspect}"
          case state
          when :start
            test.started_at   = occured_at
          when :complete
            test.completed_at = occured_at
            test.result = result
            test_runtimes[test.id] << test.runtime if test.pass?
          end
        }
      end
    end

    saving_artifacts!
    save_log_files!
    eval_hook :save_artifacts

    tearing_down!
    eval_hook :teardown

    if can_finish_test_run?
      finishing_test_run!
      eval_hook :finish_test_run
      save_test_run_artifacts!
    end

  rescue Object => e
    logger.info %(Exception:\n#{e}\n#{e.backtrace.join("\n")})
    self['exception'] = e.to_s
    self['exception:class'] = e.class.to_s
    self['exception:message'] = e.message.to_s
    self['exception:backtrace'] = e.backtrace.join("\n")
    raise # raise so resque shows this as a failed job and you can retry it
  ensure
    complete!

    begin
      save_log_files!
    rescue Exception => e
      logger.error "Error saving log files on error\n#{e}\n#{e.backtrace*"\n"}"
    end
  end

  def save_log_files!
    workspace.root.join('log').children.each{|path| save_artifact path}
    save_artifact(Hobson.temp_logfile.tap(&:flush).path, :name => 'test_run.log') if Hobson.temp_logfile.present?
  end

  def save_test_run_artifacts!
    artifacts_dir = workspace.root.join('artifacts')
    logger.debug "ARTIE DIR: #{artifacts_dir.to_s}"
    artifacts_dir.children.each{|path| save_artifact path, :content_type => `file -Ib #{path}`.gsub(/\n/,"") } if File.directory?(artifacts_dir)
  end

  def abort?
    return false if !running? || !test_run.aborted?
  end

end
