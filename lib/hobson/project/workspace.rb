require 'pathname'
require 'popen4'
require 'childprocess'
require 'sys/proctable'

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

  def prepare
    execute 'gem install bundler && bundle check || bundle install' if bundler?
    root.join('log').mkpath
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
              else
                yield nil, nil, nil, nil, nil
              end
            }
          end
        rescue ExecutionError => e
          logger.error "error running tests:\n#{e}\n#{e.backtrace*"\n"}"
          tests.each{|test|
            # reset this test if it was started but not completed
            test.reset! if test.started_at && !test.completed_at
          }
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
    pid = fork{ execute command }
    logger.debug "fork_and_execute pid(#{pid}) command(#{command})"
    while process_alive? pid
      yield
      sleep 0.5
    end
    yield # one last time
    begin Process.wait; rescue Errno::ECHILD; end
    raise ExecutionError, "#{command.inspect} crashed with exit code #{$?.exitstatus}" unless $?.success?
    $?
  ensure
    kill_process_and_its_children! pid
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
  ensure
    kill_process_and_its_children! $?.pid
  end

  # attempts to terminate the given process and it's children via TERM
  # and then
  def kill_process_and_its_children! pid
    pids = pids_for(pid)

    logger.debug "killing #{pids*' '}"

    # send term to all procs
    pids.each{|pid| send_signal_to_process pid, :TERM }

    # wait until all procs are dead but timeout after 10 seconds
    now = Time.now
    sleep 0.5 until pids.all?{|pid| !process_alive?(pid) } || (Time.now - now > 10.0)

    # if any procs are still alive
    if pids.any?{|pid| process_alive?(pid) }
      # send kill to all procs
      pids.each{|pid| send_signal_to_process pid, :KILL }
      # wait until all procs are dead
      sleep 0.5 while pids.any?{|pid| process_alive?(pid) }
    end
  end

  def process_alive? pid
    Process.waitpid2(pid, ::Process::WNOHANG).nil?
  rescue Errno::ECHILD, Errno::ESRCH
    false
  end

  def send_signal_to_process pid, signal
    if process_alive? pid
      logger.debug "sending #{signal} to #{pid}"
      Process.kill(signal.to_s, pid)
    end
  rescue Errno::ECHILD, Errno::ESRCH
  end

  # walks the ps process tree and returns an array of pids
  # of the given pid and it's children for the given pid
  def pids_for ppid, procs = Sys::ProcTable.ps.to_a
    procs.
      find_all{|p| p.ppid == ppid }.
      inject([ppid]){|pids, proc| pids + pids_for(proc.pid, procs) }
  end

  def inspect
    "#<#{self.class} project:#{project.name} root:#{root}>"
  end
  alias_method :to_s, :inspect

end
