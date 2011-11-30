class Hobson::Project::TestRun::Job

  def enqueue!
    Hobson.resque.enqueue(Hobson::Project::TestRun::Runner, test_run.project.name, test_run.id, index)
    enqueued!
  end

  def run_tests!
    self['hostname'] = `curl -s http://169.254.169.254/latest/meta-data/public-hostname`.chomp
    self['hostname'] = `hostname`.chomp if self['hostname'].blank? || !$?.success?

    checking_out_code!
    workspace.checkout! test_run.sha

    preparing!
    workspace.prepare
    eval_hook :setup

    running_tests!
    workspace.run_tests self.tests.map(&:name).sort do |name, status, result, runtime|
      test = test_run.tests[name]
      test.status  = status
      test.result  = result  if result.present?
      test.runtime = runtime if runtime.present?
    end

    saving_artifacts!
    eval_hook :save_artifacts

    tearing_down!
    eval_hook :teardown

  rescue Object => e
    logger.info %(Exception:\n#{e}\n#{e.backtrace.join("\n")})
    self['exception'] = e.message
    self['backtrace'] = e.backtrace.join("\n")
  ensure
    complete!
    save_artifact(Hobson.temp_logfile.tap(&:flush).path, 'test_run.log') if Hobson.temp_logfile.present?
  end

end
