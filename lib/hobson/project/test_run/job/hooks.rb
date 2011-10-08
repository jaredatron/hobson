class Hobson::Project::TestRun::Job

  class HookEnvironment
    attr_reader :job
    def initialize job
      @job = job
    end
    delegate :test_run, :save_artifact, :logger, :to => :job
    delegate :workspace,                         :to => :test_run
    delegate :execute, :root,                    :to => :workspace
  end

  def hook_environment
    @hook_environment ||= HookEnvironment.new(self)
  end

  # hook - evals hook files in this job instance
  def eval_hook hook
    logger.info "running #{hook} hook"
    path = workspace.root.join("test/cluster/#{hook}.rb")
    if path.exist?
      logger.info "instance evaling #{path}"
      hook_environment.instance_eval(path.read)
      true
    else
      logger.info "#{path} not found"
      false
    end
  end

end
