require 'childprocess'
require 'tempfile'

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
    execute! "git fetch && git reset --hard #{sha} && git clean -df"
  end

  def ready?
    root.exist? && root.join('.git').directory?
  end

  def prepare!
    root.parent.mkpath
    `git clone "#{project.url}" "#{root}"` or raise "unable to create workspace"
  end

  def rvm?
    root.join('.rvmrc').exist?
  end

  def bundler?
    root.join('Gemfile').exist?
  end

  def bundler
    bundler? ? %w{bundle exec} : []
  end

  def prepare
    execute! 'bundle install' if bundler?
    root.join('log').mkpath
  end

  TEST_COMMANDS = {
    'features' => %W[
      cucumber
      --quiet
      --require features
      --require #{Hobson.lib.join('hobson/cucumber')}
      --format Hobson::Cucumber::Formatter
      --format pretty --out log/cucumber
    ],
    'specs' => %W[
      rspec
      --require #{Hobson.lib.join('hobson/rspec')}
      --format Hobson::RSpec::Formatter
      --format documentation --out log/rspec
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
    %w{features specs}.each{|type|
      next if tests[type].blank?
      logger.info "running #{type} tests"
      commands = bundler + TEST_COMMANDS[type] + tests[type]
      execute! *commands do |stdout, stderr|
        stdout.split("\n").each{|line|
          if line =~ /^TEST:([^:]+):(START|COMPLETE):(\d+)(?::(PASS|FAIL|PENDING))?$/
            report_progress.call($1, $2.downcase.to_sym, Time.at($3.to_i), $4)
          end
        }
      end
    }
  end

  ExecutionError = Class.new(StandardError)

  def execute! *args, &block
    process = execute(*args, &block)
    unless process.exit_code == 0
      cmd = process.instance_variable_get(:@args).first
      logger.error "COMMAND FAILED (#{process.exit_code}) #{cmd.inspect}"
      raise ExecutionError, "COMMAND: #{cmd.inspect}\nEXIT: #{process.exit_code}"
    end
  end

  def execute *args, &block
    prepare! unless ready?
    cmd = args.join(' ')
    logger.info "executing: #{cmd.inspect}"
    process = ChildProcess.new wrap_command(cmd)
    process.io.stdout = Tempfile.new("hobson_exec")
    process.io.stderr = Tempfile.new("hobson_exec")
    stdout = File.open(process.io.stdout.path)
    stderr = File.open(process.io.stderr.path)

    Hobson::Bundler.with_clean_env{
      # TODO this should probably be somewhere better
      ENV['RAILS_ENV'] = 'test'
      ENV['DISPLAY'  ] = ':1'
      process.start
    }

    read = proc do
      out, err = stdout.read, stderr.read
      logger.debug out if out.present?
      logger.debug err if err.present?
      if (out+err).include?('Segmentation fault')
        raise ExecutionError, "#{cmd}\n\n#{out}\n#{err}"
      end
      yield out, err if block_given?
    end

    while process.alive?
      read.call
      sleep 0.25
    end

    read.call

    process
  end

  def inspect
    "#<#{self.class} project:#{project.name} root:#{root}>"
  end
  alias_method :to_s, :inspect

  private

  def wrap_command command
    command = "rvm rvmrc trust && rvm reload && #{command}" if rvm?
    command = "cd #{root} && #{command}"
    command
  end


end
