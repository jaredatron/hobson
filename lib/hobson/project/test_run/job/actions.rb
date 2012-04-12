require 'timeout'

class Hobson::Project::TestRun::Job

  Abort = Class.new(StandardError)

  def enqueue!
    Hobson.resque.enqueue(Hobson::Project::TestRun::Runner, test_run.project.name, test_run.id, index)
    enqueued!
  end

  def run_tests!
    abort?

    self['hostname'] = begin
      # try the S3 public hostname api
      Timeout::timeout(5){ `curl -s http://169.254.169.254/latest/meta-data/public-hostname`.chomp }
    rescue Timeout::Error
      Process.kill('TERM', $?.pid) rescue nil
      `hostname`.chomp
    end

    abort?

    checking_out_code!
    workspace.checkout! test_run.sha

    abort?

    preparing!
    workspace.prepare
    eval_hook :setup

    abort?

    running_tests!
    test_runtimes = test_run.project.test_runtimes
    while (batch = test_needing_to_be_run).present?
      abort?

      eval_hook :before_running_tests, :tests => batch

      abort?

      batch.each(&:trying!)
      logger.debug "running tests: \n  #{batch.map(&:id)*"  "}\n"
      workspace.run_tests(batch){ |type, name, state, occured_at, result|
        abort?

        # skip empty report
        next unless type.present?

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

    abort?

    recording_test_runtimes!
    tests.each{|test|
      test_runtimes[test.id] << test.runtime if test.pass?
    }

    abort?

    saving_artifacts!
    save_log_files!
    eval_hook :save_artifacts

    abort?

    tearing_down!
    eval_hook :teardown

  rescue Abort
    # do nothing

  rescue Object => e
    logger.info %(Exception:\n#{e}\n#{e.backtrace.join("\n")})
    self['exception'] = e.to_s
    self['exception:class'] = e.class.to_s
    self['exception:message'] = e.message.to_s
    self['exception:backtrace'] = e.backtrace.join("\n")

  ensure
    complete!
    begin
      save_log_files! unless aborted?
    rescue Exception => e
      logger.error "Error saving log files on error\n#{e}\n#{e.backtrace*"\n"}"
    end

  end

  def save_log_files!
    workspace.root.join('log').children.each{|path| save_artifact path}
    save_artifact(Hobson.temp_logfile.tap(&:flush).path, :name => 'test_run.log') if Hobson.temp_logfile.present?
  end

  def abort?
    if test_run.aborted?
      aborting!
      raise Abort
    end
  end


end
