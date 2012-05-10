require 'pathname'
require 'popen4'
require 'childprocess'

class Hobson::Project::Workspace

  attr_reader :project

  def initialize project
    @project = project
  end

  def root
    @root ||= Hobson.root + 'projects' + project.name
  end
  alias_method :path, :root

  def sha_for rev
    execute("git rev-parse #{rev}").split("\n").last
  end

  def current_sha
    sha_for 'HEAD'
  end

  # this catches the origin server hanging up execpectedly and retries up to 3 times
  def checkout! sha, tries=0
    logger.info "checking out #{sha}"
    sha = sha_for(sha)
    logger.debug "#{current_sha} current sha"
    logger.debug "#{sha} new sha"
    unless current_sha == sha
      execute "git fetch --all && git checkout --quiet --force #{sha} -- && git stash clear"
    end
    execute "git clean -dfx"
  rescue ExecutionError => e
    if e.message.include?('The remote end hung up unexpectedly') && tries < 2
      logger.error("failed to checkout code\n#{e}\n#{e.backtrace*"\n"}")
      sleep 1
      checkout! sha, tries+1
    else
      raise
    end
  end

  def exists?
    root.exist? && root.join('.git').directory?
  end
  alias_method :exist?, :exists?

  def create!
    root.parent.mkpath
    `git clone "#{project.origin}" "#{root}"` or raise "unable to create workspace"
  end

  def rvm?
    root.join('.rvmrc').exist?
  end

  def rvm_source_file
    File.expand_path('~/.rvm/scripts/rvm')
  end

  def bundler?
    root.join('Gemfile').exist?
  end

  def bundler
    bundler? ? %w{bundle exec} : []
  end

  def bundle_install!
    execute 'gem install bundler && bundle check || bundle install' if bundler?
  end

  def prepare &block
    # raise ArgumentError, 'block is required for workspace.prepare' unless block_given?
    execute 'git reset --hard && git clean -dfx'
    begin
      logger.debug "attempting to setup from stash"
      execute 'git stash apply'
    rescue ExecutionError
      logger.debug "no stash found. Preparing..."
      bundle_install!
      yield if block_given?
      root.join('log').mkpath
      # we need to add a gitkeep file to any empty directory that might have been created in setup
      root.join('log/.gitkeep').open('w'){|f| f.write("")}
      root.join('.hobson_prepared').open('w'){|f| f.write("")}
      execute 'git add -Af && git stash && git stash apply'
    end
    execute 'git reset' # empty the git index
  end

  ExecutionError = Class.new(StandardError)

  def fork_and_execute command, &block
    pid = Kernel.fork{
      logger.debug "fork(#{Process.pid}) executing command(#{command})";
      execute command
      logger.debug "fork(#{Process.pid}) exit(#{$?.exitstatus})"
      exit!
    }
    while Process.waitpid2(pid, ::Process::WNOHANG).nil?
      yield pid
      sleep 0.5
    end
    yield pid
  end

  def execute command
    create! unless exists?

    logger.info "executing: #{command}"

    command = "cd #{root.to_s.inspect} && #{command}"
    command = "source #{rvm_source_file.inspect} && rvm rvmrc trust #{root.to_s.inspect} > /dev/null && #{command}" if rvm?
    command = "bash -lc #{command.inspect}"

    # logger.debug "actually executing: #{command}"

    Hobson::Bundler.with_clean_env{
      # TODO this should probably be somewhere better
      ENV['RAILS_ENV'] = 'test'
      ENV['DISPLAY'  ] = ':1'

      output = nil
      errors = nil
      status = POpen4::popen4(command){|stdout, stderr, stdin|
        output = stdout.read
        errors = stderr.read
      }
      output.split("\n").each{|line| logger.debug line}
      errors.split("\n").each{|line| logger.error line}
      raise ExecutionError, "COMMAND FAILED TO START\n#{command}" if status.nil?
      raise ExecutionError, "COMMAND EXITED WITH CODE #{$?.exitstatus}\n#{command}\n\n#{errors}" unless $?.success?
      return output
    }
  end

  def inspect
    "#<#{self.class} project:#{project.name} root:#{root}>"
  end
  alias_method :to_s, :inspect

  private

  def logger
    @logger ||= Log4r::Logger.new("Hobson::Project::Workspace")
  end


end
