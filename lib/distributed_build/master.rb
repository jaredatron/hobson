class DistributedBuild::Master

  LOCAL_RAILS_ROOT = Pathname.new File.expand_path('../..', __FILE__)

  def build!
    logger.info "building #{current_sha} on #{slaves.length} slaves…"
    prep_slaves!
    run_tests_on_slaves!
    collect_test_results_from_slaves!
    process_test_results!
    exit!
  end

  def prep_slaves!
    parallel_exec("preping slaves"){ |slave| slave.prepare! } or
      raise "failed setting up slaves"
  end

  def run_tests_on_slaves!
    parallel_exec("running tests on slaves"){ |slave| slave.run_tests! } or build_failed!
    logger.info "tests completed in 0.000 minutes"
  end

  def collect_test_results_from_slaves!
    parallel_exec("collecting test results from slaves"){ |slave| slave.collect_test_results! }
  end

  def process_test_results!
    logger.info "processing test resuts"
    merge_cucumber_json_files
  end

  def exit!
    if build_failed?
      logger.info "build failed" and exit(1)
    else
      logger.info "build was a success" and exit(0)
    end
  end

  private

  def build_failed!
    @build_failed = true
  end

  def build_failed?
    @build_failed == true
  end

  def merge_cucumber_json_files
    all_cucumber_data = {"features" => []}
    slaves.each{ |slave|
      slave_cucumber_data = JSON.parse(slave.local_logs_path.join('cucumber.json').read)
      all_cucumber_data["features"].push *slave_cucumber_data["features"]
    }
    LOCAL_RAILS_ROOT.join('log/cucumber.json').open('w'){ |f|
      f.write all_cucumber_data.to_json
    }
  end

  def parallel_exec message
    logger.info message
    results = Parallel.map(slaves){ |slave|
      begin
        yield slave
      rescue Exception => e
        logger.fatal "Exception caught under Slave#{slave.id}"
        logger.fatal e
        raise e
      end
    }
    return true if results.all?
    logger.error "#{message} failed #{results.inspect}"
    return false
  end

  def slaves
    @slaves or begin
      @slaves = []
      slave_configs.each_with_index{ |slave_config, index|
        @slaves << Build::Slave.new(slave_config.merge!(
          :id => index,
          :sha => current_sha,
          :tests_cmd => test_commands[index]
        ))
      }
    end
  end

  def current_sha
    @current_sha ||= `git rev-parse --verify HEAD`.chomp
    # TODO confirm sha is on github
  end

  def slave_configs
    @slave_configs ||= YAML.load_file(LOCAL_RAILS_ROOT.join('config/build_slaves.yml'))
  end

  def test_commands
    @test_commands ||= begin
      [ # TEMP FOR NOW
        # "#{SPEC} spec/widgets/legos/action_header_spec.rb",
        "#{CUCUMBER} features/login.feature",
        "#{CUCUMBER} features/info_pages.feature",
      ]
    end
  end

  SPEC     = 'bundle exec spec --format pretty:log/spec.log'
  CUCUMBER = 'bundle exec cucumber --format json --out log/cucumber.json --format pretty --out log/cucumber.log'

  def logger
    @logger ||= Logging.logger['Build'].tap{|logger|
      logger.add_appenders(
        Logging.appenders.stdout,
        Logging.appenders.file(LOCAL_RAILS_ROOT.join('log/build.log'))
      )
    }
  end

end