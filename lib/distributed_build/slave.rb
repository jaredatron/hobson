class DistributedBuild::Slave

  REMOTE_RAILS_ROOT = Pathname.new("~/work/change")

  attr_reader :id, :sha, :host, :user

  def initialize options
    @id        = options[:id]
    @sha       = options[:sha]
    @host      = options[:host]
    @user      = options[:user] || 'jenkins'
    @tests_cmd = options[:tests_cmd]
  end

  def prepare!
    logger.info "preping slave"
    exec <<-SH
      git fetch &&
      git checkout #{sha} &&
      git clean -df &&
      git log -1 &&
      git status &&
      bundle &&
      bundle exec rake -tv build:prepare_slave
    SH
  end

  def run_tests!
    logger.info "Running tests: #{@tests_cmd.inspect}"
    exec @tests_cmd
  end

  RESULT_FILES = %W[
    log/test.log
    log/cucumber.json
    log/cucumber.log
    log/spec.log
  ]

  def local_logs_path
    @local_logs_path ||= Build::LOCAL_RAILS_ROOT.join("log/slave#{id}").tap(&:mkpath)
  end

  def collect_test_results!
    logger.info "collecting test results"
    RESULT_FILES.each{|path|
      remote_file_path = REMOTE_RAILS_ROOT.join(path)
      logger.debug "SCP: #{remote_file_path} -> #{local_logs_path}"
      begin
        Net::SCP.download!(host, user, remote_file_path.to_s, local_logs_path.to_s)
      rescue Net::SCP::Error
        logger.warn "FAILED TO SCP: #{remote_file_path} -> #{local_logs_path}"
      end
    }
  end

  def exec cmd
    cmd = <<-SH
      export DISPLAY=:1 &&
      cd #{REMOTE_RAILS_ROOT} &&
      #{cmd}
    SH
    logger.debug "EXEC:\n#{cmd}"
    result = ssh.execute(cmd){ |output| output.split("\n").each{|line| logger.debug(line) } }
    return result.success?
  end

  def logger
    @logger ||= Logging.logger["Build::Slave#{id}"].tap{|logger|
      logger.level = :debug
      logger.additive = !!DEBUG
      logger.add_appenders(
        Logging.appenders.file(
          Build::LOCAL_RAILS_ROOT.join("log/build-slave#{id}.log"),
          :layout => Logging.layouts.pattern(:pattern => '%m\n')
        )
      )
    }
  end

  def ssh
    @ssh ||= Net::SSH.start(host, user)
  end

end
