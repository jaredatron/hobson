require 'childprocess'
require 'tempfile'

class Hobson::Project::Workspace

  attr_reader :project

  delegate :logger, :to => :project

  def initialize project
    @project = project
  end

  def root
    @root ||= Hobson.root + 'projects' + project.name
  end

  def checkout! sha
    logger.info "checking out #{sha}"
    raise "WHOA!!! was going to git reset inside of #{root}" if defined?(RSpec)
    execute! "git fetch && git reset --hard #{sha} && git clean -df"
  end

  def tests
    @tests ||= begin
      logger.info "detecting tests"
      tests = []
      tests += Dir[root.join('spec/**/*_spec.rb')    ].first(2)
      tests += Dir[root.join('features/**/*.feature')].first(2)
      tests.map{ |path| Pathname.new(path).relative_path_from(root).to_s }.sort

      # # TEMP WHILE DEVELOPING
      # [
      #   'features/bulk_supporter_message.feature',
      #   'spec/views/widgets/legos/action_header_spec.rb',
      # ]
    end
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

  File.expand_path('../../')
  TEST_COMMANDS = {
    'features' => %W[
      cucumber
      --quiet
      --require #{Hobson.lib.join('hobson/cucumber/formatter')}
      --format Hobson::Cucumber::Formatter
      --format pretty --out log/cucumber
    ],
    'specs' => %W[
      rspec
      --require #{Hobson.lib.join('hobson/rspec/formatter')}
      --format Hobson::RSpec::Formatter
      --format documentation --out log/rspec
    ],
  }
  def run_tests tests, &report_progress

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
      execute(*(bundler + TEST_COMMANDS[type] + tests[type])) do |stdout, stderr|
        stdout.split("\n").each{|line|
          case line
          when /^PROGRESS:STARTED:(.*)$/
            report_progress.call($1, :running, nil, nil)
          when /^PROGRESS:COMPLETED:(.*):(PASS|FAIL|PENDING):([\d\.]+)$/
            report_progress.call($1, :complete, $2, $3)
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
      raise ExecutionError, "COMMAND: #{cmd.inspect}\nEXIT: #{process.exit_code}"
    end
  end

  def execute *args, &block
    cmd = args.join(' ')
    logger.info "executing: #{cmd.inspect}"
    process = ChildProcess.new "cd #{root} && #{cmd}"
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

end
