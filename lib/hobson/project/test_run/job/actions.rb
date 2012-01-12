require 'timeout'

class Hobson::Project::TestRun::Job

  def enqueue!
    Hobson.resque.enqueue(Hobson::Project::TestRun::Runner, test_run.project.name, test_run.id, index)
    enqueued!
  end

  def run_tests!
    return if test_run.aborted?

    begin
      Timeout::timeout(5){
        self['hostname'] = `curl -s http://169.254.169.254/latest/meta-data/public-hostname`.chomp
      }
    rescue Timeout::Error
    end
    self['hostname'] = `hostname`.chomp if self['hostname'].blank? || !$?.success?

    abort?
    checking_out_code!
    workspace.checkout! test_run.sha

    abort?
    preparing!
    workspace.prepare
    eval_hook :setup

    abort?
    running_tests!
    while (tests = test_needing_to_be_run).present?
      abort?
      eval_hook :before_running_tests, :tests => tests
      abort?
      names = tests.each(&:trying!).map(&:name).sort
      workspace.run_tests(names){ |name, state, time, result|
        abort?
        test = tests.find{|test| test.name == name} or next
        case state
        when :start
          test.started_at   = time
        when :complete
          test.completed_at = time
          test.result = result
        end
      }
    end
    abort?

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

  def abort?
    return false if !running? || !test_run.aborted?
    logger.info "ABORTING! (#{caller.first})"
    exit!
  end

end
