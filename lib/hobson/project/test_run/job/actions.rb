require 'timeout'

class Hobson::Project::TestRun::Job

  def enqueue!
    Hobson.resque.enqueue(Hobson::Project::TestRun::Runner, test_run.project.name, test_run.id, index)
    enqueued!
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
      while (batch = test_needing_to_be_run).present?
        break if abort?
        eval_hook :before_running_tests, :tests => batch
        break if abort?
        batch.each(&:trying!)
        logger.debug "running tests: #{batch.map(&:id).inspect}"
        workspace.run_tests(batch){ |type, name, state, occured_at, result|

          # find the test this is an update for
          test = batch.find{|test| test.id == "#{type}:#{name}" }

          # abort if we recieve a report for a test we did not expect to be running
          test or raise "status update for unknown test #{name.inspect}"

          case state
          when :start
            # if the test is reported to start more then once, ignore
            # subsequent started at times
            test.started_at ||= occured_at
          when :complete
            test.completed_at = occured_at
            # if a test result is reported more then once ignore it if
            # the test was previously reported as a failure
            test.result = result unless test.fail?
          end
        }
      end
    end

    recording_test_runtimes!
    tests.each{|test|
      test_runtimes[test.id] << test.runtime if test.pass?
    }

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
    workspace.root.join('log').children.each{|path| save_artifact path}
    save_artifact(Hobson.temp_logfile.tap(&:flush).path, :name => 'test_run.log') if Hobson.temp_logfile.present?
  end

  def abort?
    return false if !running? || !test_run.aborted?
  end

end
