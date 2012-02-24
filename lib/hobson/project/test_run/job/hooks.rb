require 'ostruct'
class Hobson::Project::TestRun::Job

  class HookEnvironment < OpenStruct
    attr_reader :job
    def initialize job, additional_data={}
      super(additional_data)
      @job = job
    end
    delegate :test_run, :save_artifact, :logger, :to => :job
    delegate :workspace,                         :to => :test_run
    delegate :execute, :root,                    :to => :workspace
  end

  # hook - evals hook files in this job instance
  def eval_hook hook, additional_data = {}
    logger.info "running #{hook} hook"
    path = workspace.root.join("config/hobson/#{hook}.rb")
    if !path.exist?
      logger.info "#{path} not found"
      return false
    end
    logger.info "instance evaling #{path}"
    begin
      HookEnvironment.new(self, additional_data).instance_eval(path.read, path.to_s, 1)
    rescue Exception => e
      e.backtrace.unshift "#{path}:0:in `instance eval'"
      raise
    end
  end

end
