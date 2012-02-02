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

  def checkout! sha
    logger.info "checking out #{sha}"
    execute "git fetch --all && git reset --hard #{sha} && git clean -df"
  end

  def exists?
    root.exist? && root.join('.git').directory?
  end
  alias_method :exist?, :exists?

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

  def run_tests tests, &report_progress
    @test_run_index += 1
    logger.info "Running Tests #{@test_run_index}: #{tests.join(' ')}"

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
      command = "cd #{root.to_s.inspect} && "
      command << "bundle exec " if bundler?
      command << test_command(type, tests[type])
      command << "; true" # we dont care about the exit status

      status_file = root.join(hobson_status_file)
      status_file.open('a'){} # touch
      status_file.open{|status|
        status.read # ignore existing content
        begin
          fork_and_execute(command) do
            status.read.split("\n").each{|line|
              if line =~ /^TEST:([^:]+):(START|COMPLETE):(\d+\.\d+)(?::(PASS|FAIL|PENDING))?$/
                yield $1, $2.downcase.to_sym, Time.at($3.to_i), $4
              end
            }
          end
        rescue ExecutionError => e
          logger.error "error running tests: #{e}"
        end
      }
    }
    tests
  end

  def hobson_status_file
    "log/hobson_status#{@test_run_index}"
  end

  def test_command type, tests
    case type.to_sym
    when :features
      %W[
        cucumber
        --quiet
        --require features
        --require #{Hobson.lib.join('hobson/formatters/cucumber')}
        --format pretty --out log/feature_run#{@test_run_index}
        --format Hobson::Formatters::Cucumber --out #{hobson_status_file}
        #{tests*' '}
      ]
    when :specs
      %W[
        rspec
        --require #{Hobson.lib.join('hobson/formatters/rspec')}
        --format documentation --out log/spec_run#{@test_run_index}
        --format Hobson::Formatters::Rspec --out #{hobson_status_file}
        #{tests*' '}
      ]
    when :test_units
      %W[echo not yet supported && false]
    end * ' '
  end

  ExecutionError = Class.new(StandardError)

  def fork_and_execute command, &block
    pid = fork{ execute command }
    logger.debug "fork_and_execute pid(#{pid}) command(#{command})"
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
