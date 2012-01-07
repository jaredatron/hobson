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
    execute 'bundle install' if bundler?
    root.join('log').mkpath
  end

  TEST_COMMANDS = {
    'features' => %W[
      cucumber
      --quiet
      --require features
      --require #{Hobson.lib.join('hobson/cucumber')}
      --format pretty
      --format pretty --out log/cucumber
      --format Hobson::Cucumber::Formatter --out log/hobson_status
    ],
    'specs' => %W[
      rspec
      --require #{Hobson.lib.join('hobson/rspec')}
      --format documentation
      --format documentation --out log/rspec
      --format Hobson::RSpec::Formatter --out log/hobson_status
    ],
  }

  def run_tests tests, &report_progress
    logger.info "Running Tests: #{tests.join(' ')}"

    # split up tests by type
    tests = tests.group_by{|path|
      case path
      when /.feature$/: 'features'
      when /_spec.rb$/: 'specs'
      when /_test.rb$/: 'test_units'
      end
    }

    # run each test type
    %w{features specs test_units}.each{|type|
      next if tests[type].blank?
      logger.info "running #{type} tests"

      command = "cd #{root.to_s.inspect} && "
      command << "bundle exec " if bundler?
      command << (TEST_COMMANDS[type] + tests[type]).join(' ')
      command << ">> log/hobson_#{type}.log"

      logger.debug "command: #{command}"

      file = root.join('log/hobson_status')
      FileUtils.touch(file)
      status = root.join('log/hobson_status').open
      process = ChildProcess.new(command)
      process.io.inherit!

      update = proc{
        status.read.split("\n").each{|line|
          if line =~ /^TEST:([^:]+):(START|COMPLETE):(\d+)(?::(PASS|FAIL|PENDING))?$/
            report_progress.call($1, $2.downcase.to_sym, Time.at($3.to_i), $4)
          end
        }
      }

      with_clean_env{ process.start }
      update.call while process.alive?
      update.call
      status.close

      if process.crashed?
        raise ExecutionError, "#{command.inspect} crashed with exit code #{process.exit_code}"
      end
    }
    tests
  end

  ExecutionError = Class.new(StandardError)

  def execute *args, &block
    create! unless exists?

    command = "cd #{root.to_s.inspect} && #{args.join(' ')}"
    command = "source #{rvm_source_file.inspect} && rvm rvmrc trust #{root.to_s.inspect} > /dev/null && #{command}" if rvm?
    command = "bash -lc #{command.inspect}"

    logger.info "executing: #{command.inspect}"

    with_clean_env{
      output = nil
      errors = nil
      status = POpen4::popen4(command){|stdout, stderr, stdin|
        output = stdout.read
        errors = stderr.read
      }
      raise ExecutionError, "#{command.inspect} could not be started" if status.nil?
      raise ExecutionError, "#{command.inspect} crashed with exit code #{$?.exitstatus}\n#{errors}" unless $?.success?
      return output
    }
  end

  def with_clean_env &block
    Hobson::Bundler.with_clean_env{
      # TODO this should probably be somewhere better
      ENV['RAILS_ENV'] = 'test'
      ENV['DISPLAY'  ] = ':1'
      return yield
    }
  end

  def inspect
    "#<#{self.class} project:#{project.name} root:#{root}>"
  end
  alias_method :to_s, :inspect

end
