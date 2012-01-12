# Hobson

A distributed test run framework built on resque

# maintenance commands

## list processes
    clear; ps aux | grep -P 'redis|hobson|resque|ruby|cucumber|rspec|firefox|chrome'

### or
    clear; ps x

## update hobson
    (cd ~/hobson_gem; git fetch && git reset --hard origin/master)

## show hobson version
    clear; (cd ~/hobson_gem; git log -1 )

## start hobson
    /etc/init.d/hobson start

## rails hobson logs
    clear; tail -n 0 -f ~/hobson/log/*

## kill hobson
    kill -2 `cat ~/hobson/hobson.pid`

## kill everything
    clear; killall -4 ruby; killall firefox; killall chrome; killall chromedriver; killall searchd; ps x

## Setup

  0. Add a config/hobson.yml file that looks like this to your development workstation

        ---
        :redis:
          :host: ec2-0-0-0-0.compute-1.amazonaws.com
          :db: 3
          :namespace: 'hobson'
          :port: 6380

  0. Add the same config to any machines you intend to be workers with an additional workspace entry

        :workspace: /Users/change/work/change

  0. add hobson to applications your Gemfile
  0. run:

        $ bundle install
        $ bundle exec hobson

  0. to start a worker run:

        $ bundle exec hobson work

  0. to kick off a "test run" run:

        $ bundle exec hobson run

# TODO

  0. fix links to worker hosts (somehow detect S3)
  0. update ets. runtime logic to no longer need a minumum est runtime.
    * you can enable 0 est runtimes by collecting a set of 0 runtimes and pushing on the smallest or shortest job set
  0. add detection of unpushed sha
  0. find a way to confirm we're running all tests
  0. add a Hobson & Project settings page for the following settings
    * min / max jobs per test_run
    * min / max tests per job
    * auto re-run failed tests

  0. add test_run runtime estimation taking into account avg. setup & teardown
  0. add custom formatters that dump failures to individual files and upload those artifacts immediately
  0. add rerun failed tests functionality &|| add auto rerun of failed tests
  0. rename test_run/job/application etc.



# Life cycle

  0. enqueue a ScheduleTestRun resque job for a given sha
    * check out the given sha
    * prepare the environment
    * discover the tests that are needed to run
    * add a list of tests to the TestRun data
    * schedule N RunTests resque jobs for Y jobs (balancing is done in this step)
    * teardown environment
  0. Hobson::RunTests jobs are run
    * check out the given sha
    * prepare the environment
    * run the subset of tests
    * report the result for each test (with backtrace and associated artifacts)
    * teardown environment

# running tests
  * check out the given sha
  * prepare the environment
  * execute test command (using PTY for non-blocking read)
    * use a special formatter that writes the current test to a file followed by its result
    * loop and read from PTY stdin and update redis with that status of what test is being run and then its status
  * report the result for each test (with backtrace and associated artifacts)
  * teardown environment








# Objects


### Hobson::Project
  * name       (String)
  * git url    (String)
  * test runs  (Hobson::Project::TestRun)


### Hobson::Project::TestRun
  * id                (String)
  * sha               (String)
  * scheduled_build   (Datetime)
  * started_building  (Datetime)
  * scheduled_jobs    (Datetime)
  * tests             (Hobson::Project::TestRun::Tests)


### Hobson::Project::TestRun::Tests
  * tests (Hobson::Project::TestRun::Tests::Test)

### Hobson::Project::TestRun::Tests::Test
  * name        (String)
  * state       (String)  [waiting|started|complete]
  * result      (String)  [PASS|FAIL|PENDING]
  * est_runtime (Float)   [seconds]
  * runtime     (Float)   [seconds]
  * job         (Integer) [job index]

### Hobson::Project::TestRun::Job
  * index                 (Integer)
  * scheduled_at          (Datetime)
  * checking\_out_code    (Datetime)
  * preparing_environment (Datetime)
  * running_tests         (Datetime)
  * saving_artifacts      (Datetime)
  * tearing_down          (Datetime)
  * completed_at          (Datetime)

# TestRun Redis Hash
  {
    sha                               =>
    scheduled_build_at                => "Fri Nov 18 10:15:03 -0800 2011"
    started_building_at               => "Fri Nov 18 10:15:03 -0800 2011"
    scheduled_jobs_at                 => "Fri Nov 18 10:15:03 -0800 2011"
    job:#{n}:scheduled_at             => "Fri Nov 18 10:15:03 -0800 2011"
    job:#{n}:checking_out_code_at     => "Fri Nov 18 10:15:03 -0800 2011"
    jon:#{n}:preparing_environment_at => "Fri Nov 18 10:15:03 -0800 2011"
    jon:#{n}:running_tests_at         => "Fri Nov 18 10:15:03 -0800 2011"
    jon:#{n}:saving_artifacts_at      => "Fri Nov 18 10:15:03 -0800 2011"
    jon:#{n}:tearing_down_at          => "Fri Nov 18 10:15:03 -0800 2011"
    jon:#{n}:completed_at             => "Fri Nov 18 10:15:03 -0800 2011"
    test:#{test_name}:status          => ("waiting"|"started"|"complete")
    test:#{test_name}:result          => ("pass"|"fail"|"pending")
    test:#{test_name}:est_runtime     => 23.854
    test:#{test_name}:runtime         => 23.854
  }





