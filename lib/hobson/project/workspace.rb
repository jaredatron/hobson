require 'pathname'
require 'popen4'
require 'childprocess'

class Hobson::Project::Workspace

  attr_reader :project, :test_run_index

  delegate :logger, :to => :project

  def initialize project
    @project = project
    @test_run_index = 0
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

  def checkout! sha
    logger.info "checking out #{sha}"
    sha = sha_for(sha)
    logger.debug "#{current_sha} current sha"
    logger.debug "#{sha} new sha"
    unless current_sha == sha
      execute "git fetch --all && git checkout --quiet --force #{sha} -- && git stash clear"
    end
    execute "git clean -dfx"
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
      root.join('.hobson_prepared').open('w'){|f| f.write("")}
      execute 'git add -Af && git stash && git stash apply'
    end
    execute 'git reset' # empty the git index
  end

  def run_tests tests, &report_progress
    @test_run_index += 1
    logger.info "Running Tests #{@test_run_index}: #{tests.join(' ')}"

    # split up tests by type
    tests.group_by(&:type).each{|type, tests|
      logger.info "Running #{tests.size} #{type} tests"
      next if tests.empty?

      command = "cd #{root.to_s.inspect} && "
      command << "bundle exec " if bundler?
      command << test_command(type, tests.map(&:name))
      command << "; true" # we dont care about the exit status

      status_file = root.join(hobson_status_file)
      status_file.open('w'){|f|f.write('')} # touch & empty
      status_file.open{|status|
        begin
          fork_and_execute(command) do
            status.read.split("\n").each{|line|
              if line =~ /^TEST:([^:]+):([^:]+):(START|COMPLETE):(\d+\.\d+)(?::(PASS|FAIL|PENDING))?$/
                type, name, state, occured_at, result = $1, $2, $3.downcase.to_sym, Time.at($4.to_i), $5
                yield type, name, state, occured_at, result
              end
            }
          end
        rescue ExecutionError => e
          logger.error "error running tests:\n#{e}\n#{e.backtrace*"\n"}"
          tests.each{|test| test.reset! if test.started_at && !test.completed_at}
        end
      }
    }
  end

  def hobson_status_file
    "log/hobson_status#{@test_run_index}"
  end

  def test_command type, tests
    case type.to_sym
    when :scenario
      %W[
        cucumber
        --quiet
        --require features
        --require #{Hobson.lib.join('hobson/formatters/cucumber.rb')}
        --format pretty --out log/feature_run#{@test_run_index}
        --format Hobson::Formatters::Cucumber --out #{hobson_status_file}
        #{tests.map{|name| '--name ' + "^#{Regexp.escape(name)}$".inspect }*' '}
      ]
    when :spec
      %W[
        rspec
        --require #{Hobson.lib.join('hobson/formatters/rspec.rb')}
        --format documentation --out log/spec_run#{@test_run_index}
        --format Hobson::Formatters::Rspec --out #{hobson_status_file}
        #{tests*' '}
      ]
    when :test_unit
      %W[echo not yet supported && false]
    else
      raise "unknown test type #{type}"
    end * ' '
  end

  ExecutionError = Class.new(StandardError)

  def fork_and_execute command, &block
    logger.debug "forking and executing command(#{command})"
    pid = Kernel.fork{
      logger.debug "fork(#{Process.pid}) executing command(#{command})";
      execute command
      logger.debug "fork(#{Process.pid}) exit(#{$?.exitstatus})"
      exit! $?.exitstatus
    }
    logger.debug "fork pid(#{pid})"
    while Process.waitpid2(pid, ::Process::WNOHANG).nil?
      yield
      sleep 0.5
    end
    yield
    begin Process.wait; rescue Errno::ECHILD; end
    raise ExecutionError, "#{command.inspect} crashed with exit code #{$?.exitstatus}" unless $?.success?
    $?
  end

  def execute command
    create! unless exists?

    logger.info "executing: #{command}"

    command = "cd #{root.to_s.inspect} && #{command}"
    command = "source #{rvm_source_file.inspect} && rvm rvmrc trust #{root.to_s.inspect} > /dev/null && #{command}" if rvm?
    command = "bash -lc #{command.inspect}"

    logger.debug "actually executing: #{command}"

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

end
