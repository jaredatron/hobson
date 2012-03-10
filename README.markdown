# Hobson

A distributed test run framework built on resque.

Hobson distributes your test suite across N machines aggregating the results live on a beautiful locally run web app.

## Hobson can:

  * auto balance tests across jobs
  * preserve log files and other artifacts to the cloud
  * automatically re-run failed tests
  * monitor a git repo reference and auto run new SHAs (a basic CI)

## Special Thanks

  to Change.org for funding this project
  and to Charles Finkel for solving a heap of bugs

---

# How do I setup Hobson?

## First Setup Hobson's Two Centralized Dependancies & config.yml:

  0. Setup a redis-server (We recommend a dedicated redis-server instance for Hobson lest you run the chance of your data being lost when a projects test run flushes all databases. If anyone knows how to protect an individual db please contact me)
  0. Setup a cloud storage like S3 (anything Fog supports) (this is used to upload artifacts like logs)
  0. Create your Hobson config.yml like so

        ---
        :redis:
          :host: 127.0.0.1
          :port: 6380
        :storage:
          :provider: AWS
          :aws_secret_access_key: INTENTIONALLY_LEFT_BLANK
          :aws_access_key_id: INTENTIONALLY_LEFT_BLANK
          :directory: BUCKET_NAME_HERE

## Now Setup Your Hobson (Resque) Workers

  0. setup N machines capable of running your project's test suite
  0. on one of these machines start an isolated redis-server (on another port)
    * I don't recommend sharing redis with your project(s)
    * this is the redis you'll reference in your config.yml files later on
  0. do this on all of your worker machines:
    0. checkout the hobson repo (in ~/hobson for example)
    0. `cd ~/hobson && bundle install`
    0. make a directory for hobson to work within (~/hobson_workspace for example)
    0. create a ~/hobson_workspace/config.yml file that looks like [this](https://github.com/deadlyicon/example_hobson_project/blob/master/config/hobson.yml)
    0. …(here is where you would setup /etc/init.d/hobson and or monit etc.)
    0. start your workers by running this:
      * `cd ~/hobson_workspace && ~/hobson/bin/hobson work`

### Now Preparing Your Project(s) To Be Run By Hobson

  0. DO NOT ADD hobson TO YOUR GEMFILE OR PROJECT
  0. checkout the hobson repo on your workstation (in ~/hobson for example)
  0. copy the same config.yml file you created earlier to $YOUR_PROJECT/config/hobson.yml
  0. add any hooks you might need [(see these examples)](https://github.com/deadlyicon/example_hobson_project/blob/master/config/hobson)

### Now Kicking Off A Test Run

  just run `hobson test` from with you project

  Something like `cd $YOUR_PROJECT && ~/hobson/bin/hobson test`

  This should start the local Hobson web server opened to your new test run's status page

## Debugging Hobson

  Hobson is very alpha. The main issue you might face is resque worker death. To get visiblity
  into this run `hobson resque-web` to see the status of resque.

---

## How it works

  Once you setup N machines running a hobson resque worker all you need to do
  is run '`hobson test`' and Hobson will distribute your test suite across N
  workers and aggregate the results live into a single web page.

Hobson is completely decentralized apart from it's persistence in a single
redis server. There is no central Hobson server process. Hobson is just a
collection of resque workers and local sintra app.

## The Common life cycle:

  0. cd into your project directory and run 'hobson test'
  0. this launches the local hobson web application and opens the status page for the test run you've just created and schedules a 'build test run' job for the current git repo and SHA
  0. one of your resque workers picks up this job, checks out the given sha and scans it for 'tests'
  0. these tests are then balanced across N resque jobs. (N being the number of resque workers you have) and then N 'test run' resque jobs are now scheduled
  0. your cluster of resque workers then starts running their subset of your test suite in parallel
  0. as each resque worker completes starts a test or completed a test the test run status page is updated
  0. Once complete you'll end up with something like the following screenshot
  0. Once a worker completes it's task the log files are uploaded to S3

# A Successful Test Run Status Page:

looks something like this…

![Green Build](http://dl.dropbox.com/u/1090585/Slingshot/Pictures/Screen%20Shot%202012-01-17%20at%2011.25.38%20AM.png)

---
# Hooks

Hobson looks in ${APP_ROOT}/config/hobson/ for the following hooks. These hooks are evaluated within the hobson process giving you access to the internal API (see code for more details).

  * setup.rb
    - run once after `bundle install` but before tests are run
  * before_running_tests.rb
    - run before each test command is executed
  * save_artifacts.rb
    - run once after all tests have been run
  * teardown.rb
    - run once after test run is complete

---

# How does my app know about hobson?

The hobson command looks in ${APP_ROOT}/config/hobson.yml for the redis server it should connect to.

# What does Hobson consider a test?

Right now a 'test' is an individual feature or spec file. In the near future we'll be increasing cucumber feature granularity to the individual feature level. Unfortunately because specs can be defined dynamically it's non-trivial if not impossible to individually address each spec so we have to stay at the level of the file for rspec.


---

# Internals

  Hobson persists everything in redis using the following models.

        ---
        :redis:
          :host: ec2-0-0-0-0.compute-1.amazonaws.com
          :port: 6380
        :s3:
          :access_key_id: INTENTIONALLY_LEFT_BLANK
          :secret_access_key: INTENTIONALLY_LEFT_BLANK
          :bucket: INTENTIONALLY_LEFT_BLANK


## Setup A Hobson (Resque) Worker

  0. Checkout hobson somewhere. For example we'll say you checked it out in ~/hobson_gem
  0. Install hobson's gems '`(cd ~/hobson_gem/ && bundle)`'
  0. Create a hobson workspace directory somewhere. For example we'll use ~/hobson
  0. Place your config.yml here ~/hobson/config.yml
  0. …(here is where you would setup /etc/init.d/hobson and or monit etc.)
  0. Start hobson in the the working directory '`cd ~/hobson && ~/hobson_gem/bin/hobson work --daemonize`'
  0. Rinse and repeat

---

# Internals

  Hobson persists everything in redis using the following models.

## Hobson Objects


### Hobson::Project
  * name       (String)
  * git_url    (String)
  * test_runs  (Hobson::Project::TestRun)

### Hobson::TestRun
  * project           (string)
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

---

# TODO

  * use redis index sets instead of using the keys command
  * add a test run post processing job to do things like compile SimpleCov reports
  * add a requested-by tag to show what engineer created what test_run
  * refactor feature tests to mean individual scenarios rather then .feature file
  * detect when a sha isn't on origin and error
  * update balancing logic to be aware of 0 est runtimes rather then using 0.1 as a hack
  * find a fix for empty test files
    * when a test file is empty it's never updated by the hobson status formatter and the whole test run is hung
  * improve the way Hobson uses redis. It's wicked slow atm.
  * add hobson & hobson project configuration options
    * min / max jobs per test_run
    * min / max tests per job
    * auto re-run failed ? tests
  * improve test_run runtime estimation taking into account avg. setup & teardown
  * add custom formatters that dump failures to individual files and upload those artifacts immediately
