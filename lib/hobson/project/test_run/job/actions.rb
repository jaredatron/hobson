class Hobson::Project::TestRun::Job

  def enqueue!
    Hobson.resque.enqueue(Hobson::Project::TestRun::Runner, test_run.project.name, test_run.id, index)
    enqueued!
  end

  def run_tests!
    return if aborting?

    self['hostname'] = `curl -s http://169.254.169.254/latest/meta-data/public-hostname`.chomp
    self['hostname'] = `hostname`.chomp if self['hostname'].blank? || !$?.success?

    unless aborting?
      checking_out_code!
      workspace.checkout! test_run.sha
    end

    unless aborting?
      preparing!
      workspace.prepare
      eval_hook :setup
    end

    unless aborting?
      running_tests!
      while (tests = test_needing_to_be_run).present?
        break if aborting?
        eval_hook :before_running_tests, :tests => tests
        names = tests.each(&:trying!).map(&:name).sort
        workspace.run_tests(names){ |name, state, time, result|
          test = tests.find{|test| test.name == name} or next
          case state
          when :start
            test.started_at   = time
          when :complete
            test.completed_at = time
            test.result = result
          end
          break if aborting?
        }
      end
    end

    saving_artifacts!
    save_log_files!
    eval_hook :save_artifacts

    tearing_down!
    eval_hook :teardown

  rescue Object => e
    logger.info %(Exception:\n#{e}\n#{e.backtrace.join("\n")})
    self['exception'] = "#{e.class}: #{e.message}"
    self['backtrace'] = e.backtrace.join("\n")
  ensure
    complete!
    begin
      save_log_files!
    rescue Exception => e
      logger.error "Error saving log files on error"
    end
  end

  def save_log_files!
    workspace.root.join('log').children.each{|path| save_artifact path}
    save_artifact(Hobson.temp_logfile.tap(&:flush).path, 'test_run.log') if Hobson.temp_logfile.present?
  end

end
