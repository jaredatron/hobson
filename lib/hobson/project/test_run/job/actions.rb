require 'timeout'

class Hobson::Project::TestRun::Job

  def enqueue!
    worker = test_run.fast_lane ? Hobson::Project::TestRun::Job::FastLaneRunner : Hobson::Project::TestRun::Job::Runner
    Hobson.resque.enqueue(worker, test_run.project.name, test_run.id, index)
    enqueued!
  end

  def prepare_workspace!
    return if abort?
    checking_out_code!
    workspace.checkout! test_run.sha
    return if abort?
    preparing!
    workspace.prepare{ eval_hook :setup }
  end

  def run_tests!
    return if test_run.aborted?
    logger.info 'starting run tests action'

    self['hostname'] = Timeout::timeout(5){ # try the S3 public hostname api
      `curl -s http://169.254.169.254/latest/meta-data/public-hostname`.chomp
    } rescue `hostname`.chomp

    prepare_workspace!

    unless abort?
      running_tests!
      while_tests_needing_to_be_run{|tests, index|
        raise "max test executions reached. something is very wrong with your code. Please see the logs." if index > 10
        break if abort?
        eval_hook :before_running_tests, :tests => tests
        break if abort?
        TestExecutor.new(self, index, tests)
      }
    end

    tearing_down!
    eval_hook :teardown

    if (incomplete_jobs = test_run.redis.decr("#{test_run.redis_key}:number_of_incomplete_jobs")) == 0
      post_processing!
      test_run.reload! # reload the test_run so the post_process hook gets fresh data
      eval_hook :post_process
    else
      logger.info "exiting with #{incomplete_jobs} job left. Not post processing."
    end

    saving_artifacts!
    save_log_files!
    eval_hook :save_artifacts

  rescue Object => e
    test_run.errored!
    logger.info %(Exception:\n#{e}\n#{e.backtrace.join("\n")})
    self['exception'] = e.to_s
    self['exception:class'] = e.class.to_s
    self['exception:message'] = e.message.to_s
    self['exception:backtrace'] = e.backtrace.join("\n")
    save_log_files! rescue nil
    raise # raise so resque shows this as a failed job and you can retry it
  ensure
    complete!
  end

  def save_log_files!
    log_dir_path = workspace.root.join('log')
    return unless log_dir_path.exist?
    Hobson.logger.outputters.each{|o| o.try(:flush) } # flush all log output
    log_dir_path.children.each{|path| save_artifact path}
    save_artifact(Hobson.temp_logfile.tap(&:flush).path, :name => 'test_run.log') if Hobson.temp_logfile.present?
  end

  def abort?
    test_run.aborted? || test_run.errored?
  end

end
