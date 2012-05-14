require 'sys/proctable'

class Hobson::Project::TestRun::Job::TestExecutor

  delegate :workspace, :to => :@job

  def initialize job, index, tests
    @job, @index, @tests       = job, index, tests
    @relative_status_file_path = "log/hobson_status#{index}"
    @status_file_path          = workspace.root.join(@relative_status_file_path)
    @testrun_log_file_path     = workspace.root.join('log/test.log')

    logger.error "executing tests (#{@index}):\n\t#{@tests.map(&:id).join("\n\t")}"
    touch @testrun_log_file_path
    touch @status_file_path

    # open test logfile and status file
    @status_file      = @status_file_path.open("r:UTF-8")
    @testrun_log_file = @testrun_log_file_path.open("r:UTF-8")

    # ignore existing content
    @testrun_log_file.read
    @status_file.read

    workspace.fork_and_execute(command){ |pid|
      # every 0.5 seconds while our tests are executing

      if @job.abort?
        kill_process!(pid)
        break
      end

      if execution_hung?
        if @current_test.nil?
          logger.warn "test execution hung"
        else
          logger.warn "test execution hung running test #{@current_test.try(:id)}"
          @current_test.hung!
        end

        kill_process!(pid)
        break
      end

      check_for_status_updates!
    }
  rescue Hobson::Project::Workspace::ExecutionError => e
    logger.error "error running tests:\n#{e}\n#{e.backtrace*"\n"}"
  ensure
    # reset_incomplete_tests!
    unfinished_tests = tests.find_all(&:running?)
    if unfinished_tests.present?
      logger.error("The following tests started but never finished\n#{unfinished_tests.map(&:id)*"\n"}")
      unfinished_tests.each(&:reset!)
    end
    @testrun_log_file.try(:close)
    @status_file.try(:close)
  end

  private

  def touch path
    path.open('a'){}
  end

  def reset_incomplete_tests!
    @tests.each{|test| test.reset! if test.started_at && !test.completed_at}
  end

  def kill_process! pid
    logger.warn("killing test execution pid(#{pid})")

    # kill the whole family
    procs = Sys::ProcTable.ps

    find_all_children = proc{|pid|
      procs.find_all{|proc| proc.ppid == pid}
    }

    find_all_descendants = proc{|pid|
      children = find_all_children.call(pid)
      children + children.inject([]){|grand_children, proc|
        grand_children + find_all_descendants.call(proc.pid)
      }
    }

    descendants = find_all_descendants.call(pid)
    Process.kill('TERM', pid) rescue nil
    sleep 1
    Process.kill('KILL', pid) rescue nil
    while descendants.present?
      descendants.select!{|proc| Sys::ProcTable.ps(proc.pid) rescue nil } # reduce
      descendants.each{|proc| Process.kill('kill', proc.pid) rescue nil }
    end
  end

  def execution_idle_limit
    10.minute
  end

  def testrun_log_file_has_new_content?
    @testrun_log_file.read.present? rescue false
  end

  def execution_hung?
    @last_time_there_was_log_content ||= Time.now
    @last_time_there_was_log_content   = Time.now if testrun_log_file_has_new_content?
    Time.now - @last_time_there_was_log_content > execution_idle_limit
  end

  def check_for_status_updates!
    # look for updates in the status file
    update = "#{@partial_update}#{@status_file.read}"
    @partial_update = nil

    update.split("\n").each{|update| # for each update
      logger.debug "UPDATE -> #{update.inspect}"
      if update =~ /^TEST:([^:]+):([^:]+):(START|COMPLETE):(\d+\.\d+)(?::(PASS|FAIL|PENDING|ERROR))?$/
        type, name, state, occured_at, result = $1, $2, $3.downcase.to_sym, Time.at($4.to_i), $5
        test_id = "#{type}:#{name}" # this is a lame duplication of logic
      else
        @partial_update = update
        next
      end

      test = @tests.find{|test| test.id == test_id }
      test or raise "received status update for unknown test #{test_id.inspect}"

      case state
      when :start
        if @current_test.present? && @current_test.id != test.id
          raise "#{test.id} started before #{@current_test.id} ever finished"
        end
        @current_test = test.tap(&:trying!)
        test.started_at = occured_at
      when :complete
        test.completed_at = occured_at

        # only update the test result if it's never recieved a result or it recieved a pass
        # this handles the case where a test result is reported twice
        # this happens when there are more then once top level describe blocks in spec files
        test.send(:"#{result.downcase}!") unless test.fail?

        # persists passing runtimes in the projects cache for future estimates
        @job.test_run.project.test_runtimes[test.id] << test.runtime if test.pass?
        @current_test = nil
      end
    }
  end

  # this should all be moved to the responsability of the project we're running
  # by giving them a library to include seperate from hobson proper
  def command
    @tests.group_by(&:type).map{ |type, tests|
      command_for_type = send(:"#{type}_command", tests)
      workspace.bundler? ? "bundle exec #{command_for_type}; true" : command_for_type
    }.join('; ')
  end

  def scenario_command tests
    %W[
      cucumber
      --quiet
      --strict
      --require features
      --require #{Hobson.lib.join('hobson/formatters/cucumber.rb')}
      --format pretty --out log/feature_run#{@index}
      --format Hobson::Formatters::Cucumber --out #{@relative_status_file_path}
      #{tests.map{|test| '--name ' + "^#{Regexp.escape(test.name)}$".inspect }*' '}
    ] * ' '
  end

  def spec_command tests
    %W[
      rspec
      --require #{Hobson.lib.join('hobson/formatters/rspec.rb')}
      --format documentation --out log/spec_run#{@index}
      --format Hobson::Formatters::Rspec --out #{@relative_status_file_path}
      #{tests.map(&:name)*' '}
    ] * ' '
  end

  private

  def logger
    @logger ||= Log4r::Logger.new("Hobson::Project::TestRun::Job::TestExecutor")
  end

end
