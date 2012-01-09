require 'pathname'
require 'popen4'
require 'childprocess'

class Hobson::Project::Workspace

  attr_reader :project

  delegate :logger, :to => :project

  def initialize project
    @project = project
  end

  # TODO rename root to path
  def root
    @root ||= Hobson.root + 'projects' + project.name
  end

  def checkout! sha
    logger.info "checking out #{sha}"
    execute "git fetch && git reset --hard #{sha} && git clean -df"
  end

  def exists?
    root.exist? && root.join('.git').directory?
  end

  def create!
    root.parent.mkpath
    `git clone "#{project.url}" "#{root}"` or raise "unable to create workspace"
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

  def prepare
    execute 'bundle check || bundle install' if bundler?
    root.join('log').mkpath
  end

  TEST_COMMANDS = {
    'features' => %W[
      cucumber
      --quiet
      --require features
      --require #{Hobson.lib.join('hobson/cucumber')}
      --format pretty --out log/cucumber
      --format Hobson::Cucumber::Formatter --out log/hobson_status
    ],
    'specs' => %W[
      rspec
      --require #{Hobson.lib.join('hobson/rspec')}
      --format documentation --out log/rspec
      --format Hobson::RSpec::Formatter --out log/hobson_status
    ],
  }

  def run_tests tests, &report_progress
    logger.info "Running Tests: #{tests.join(' ')}"

    # split up tests by type
    tests = tests.group_by{|path|
      case path
      when /.feature$/; 'features'
      when /_spec.rb$/; 'specs'
      when /_test.rb$/; 'test_units'
      end
    }

    # run each test type
    %w{features specs test_units}.each{|type|
      next if tests[type].blank?
      logger.info "running #{type} tests"

      command = "cd #{root.to_s.inspect} && "
      command << "bundle exec " if bundler?
      command << (TEST_COMMANDS[type] + tests[type]).join(' ')
      command << "; true" # we dont care about the exit status

      logger.debug "command: #{command}"

      file = root.join('log/hobson_status')
      FileUtils.touch(file)
      status = root.join('log/hobson_status').open

      fork_and_execute(command){
        status.read.split("\n").each{|line|
          if line =~ /^TEST:([^:]+):(START|COMPLETE):(\d+)(?::(PASS|FAIL|PENDING))?$/
            report_progress.call($1, $2.downcase.to_sym, Time.at($3.to_i), $4)
          end
        }
      }
      status.close
    }
    tests
  end

  ExecutionError = Class.new(StandardError)

  def fork_and_execute command, &block
    pid = fork{ execute command }
    logger.debug "PID:#{pid}"
    while Process.waitpid2(pid, ::Process::WNOHANG).nil?
      yield
      sleep 0.1
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
      raise ExecutionError, "#{command.inspect} could not be started" if status.nil?
      raise ExecutionError, "#{command.inspect} crashed with exit code #{$?.exitstatus}\n#{errors}" unless $?.success?
      return output
    }
  end


  def inspect
    "#<#{self.class} project:#{project.name} root:#{root}>"
  end
  alias_method :to_s, :inspect

end
