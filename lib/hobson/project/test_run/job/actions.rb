require 'timeout'

class Hobson::Project::TestRun::Job

  def enqueue!
    Hobson.resque.enqueue(Hobson::Project::TestRun::Runner, test_run.project.name, test_run.id, index)
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
        break if abort?
        eval_hook :before_running_tests, :tests => tests
        break if abort?
        TestExecutor.new(self, index, tests)
      }
    end

    saving_artifacts!
    save_log_files!
    eval_hook :save_artifacts

    tearing_down!
    eval_hook :teardown

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
    log_dir_path = workspace.root.join('log')
    return unless log_dir_path.exist?
    log_dir_path.children.each{|path| save_artifact path}
    save_artifact(Hobson.temp_logfile.tap(&:flush).path, :name => 'test_run.log') if Hobson.temp_logfile.present?
  end

  def abort?
    test_run.aborted? || test_run.errored?
  end

end
