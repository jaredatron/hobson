class Hobson::Project::TestRun::Job

  def enqueue!
    # Resque::Job.create(:run_tests, Hobson::RunTests, test_run.id, index)
    Resque.enqueue(Hobson::RunTests, test_run.project.name, test_run.id, index)
    enqueued!
  end

  def run_tests!
    Hobson.start_logging_to_a_file!
    self['hostname'] = `curl -s http://169.254.169.254/latest/meta-data/public-hostname`.chomp
    self['hostname'] = `hostname`.chomp if self['hostname'].empty?

    checking_out_code!
    workspace.checkout! test_run.sha

    preparing!
    workspace.prepare
    eval_hook :prepare

    running_tests!
    workspace.run_tests tests.map(&:name).sort do |name, status, result, runtime|
      test = tests[name]
      test.status  = status
      test.result  = result  if result.present?
      test.runtime = runtime if runtime.present?
    end

    saving_artifacts!
    eval_hook :save_artifacts

    tearing_down!
    eval_hook :teardown

  rescue Exception => e
    logger.info %(Exception:\n#{e}\n#{e.backtrace.join("\n")})
    self['exception'] = e.message
    self['backtrace'] = e.backtrace.join("\n")
  ensure
    complete!
    save_artifact(Hobson.logfile_path, 'test_run.log') if Hobson.logfile_path.present?
  end

end
