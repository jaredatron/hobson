require 'time'

require 'sinatra/base'
require 'sinatra/partial'
require 'vegas'
require 'haml'
require 'sass'

require "active_support/dependencies/autoload"

require 'action_view/helpers/capture_helper'
require 'action_view/helpers/date_helper'

# lolz
I18n.load_path << $:.map{|path| File.join(path,'action_view/locale/en.yml') }.find{|path| File.exist?(path) }

class Hobson::Server < Sinatra::Base
  register Sinatra::Partial

  # patch Vegas::Runner to start a redis slave if the server needs to be started
  # but before it forks
  class Runner < Vegas::Runner
    def check_for_running path=nil
      super
      Hobson.use_redis_slave!
    end
  end

  def self.start! options={}
    Runner.new(self, 'hobson', options)
  end

  root = Pathname.new(File.expand_path('..', __FILE__)) + 'server'

  use Rack::MethodOverride

  set :protection,    :except => :frame_options
  set :views,         root + "views"
  set :public_folder, root + "public"
  set :static,        true
  set :partial_underscores, true

  require 'hobson/server/helpers'
  helpers Hobson::Server::Helpers
  helpers ActionView::Helpers::DateHelper

  not_found do
    '404'
  end

  get '/screen.css' do
    sass :screen
  end

  get "/" do
    redirect ci_path
  end


  # ci

  # ci dashboard
  get '/ci' do
    haml :ci
  end

  # ci project refs

  # index
  get "/ci/project_refs" do
    haml :'ci/project_refs/index'
  end

  # new
  get "/ci/project_refs/new" do
    haml :'ci/project_refs/new'
  end

  # create
  post "/ci/project_refs/new" do
    project_name, ref = params['project_ref'].values_at("project_name", "ref")
    Hobson::CI::ProjectRef.create(project_name, ref)
    redirect ci_path
  end

  # show
  get "/ci/project_refs/:project_name/:ref" do
    haml :'ci/project_refs/show'
  end

  # update
  post "/ci/project_refs/:project_name/:ref" do
    raise "NOT IMP"
    redirect project_ref_path
  end

  # update
  get "/ci/project_refs/:project_name/:ref/run_tests" do
    redirect test_run_path project_ref.run_tests!
  end

  # delete
  delete "/ci/project_refs/:project_name/:ref" do
    project_ref.delete
    redirect '/ci'
  end

  # check project refs for new commits
  MAX_CHECK_FOR_CHANGES_INTERVAL = 60 # seconds
  get '/ci/check-for-changes' do
    now = Time.now
    @@last_time_we_checked_for_changes ||= now - MAX_CHECK_FOR_CHANGES_INTERVAL
    seconds_since_last_check = now - @@last_time_we_checked_for_changes
    response = {:success => true, :seconds_since_last_check => seconds_since_last_check, :checked => false}
    if seconds_since_last_check >= MAX_CHECK_FOR_CHANGES_INTERVAL
      @@last_time_we_checked_for_changes = now
      project_refs.each{|project_ref|
        # start a new test run if we're not already running tests and there is a new sha that hasnt been tested yet
        project_ref.run_tests! if !project_ref.running_tests? && project_ref.need_test_run?
      }
      response[:checked] = true
    end
    response.to_json
  end

  # projects

  # index
  get "/projects" do
    haml :'projects/index'
  end

  # new
  get "/projects/new" do
    haml :'projects/new'
  end

  # create
  put "/projects" do
    project = params['project']
    @project = Hobson::Project.create(project['origin'], project['name'])
    @project.homepage = project['homepage'] if project['homepage'].present?
    redirect project_path(@project)
  end

  # show
  get "/projects/:project_name" do
    if project.new_record?
      redirect "#{new_project_path}?name=#{project.name}"
    else
      haml :'projects/show'
    end
  end

  # edit
  get "/projects/:project_name/edit" do
    haml :'projects/edit'
  end

  # update
  post "/projects/:project_name" do
    project.url = params['url']
    redirect project_path
  end

  # delete
  delete "/projects/:project_name" do
    project.delete
    redirect projects_path
  end

  # project test runs

  # index
  get "/projects/:project_name/test_runs" do
    haml :'projects/test_runs/index'
  end

  # new
  get "/projects/:project_name/test_runs/new" do
    @test_runs = true # this makes the breadcrumb work
    haml :'projects/test_runs/new'
  end

  # create
  post "/projects/:project_name/test_runs" do
    test_run = params['test_run']
    @test_run = project.run_tests!(
      :sha => test_run['sha'],
      :requestor => test_run['requestor']
    )
    redirect test_run_path(@test_run)
  end

  # show

  TEST_RUN_SHOW_PAGE_CACHE_PREFIX = "test_run_show_page_"
  get "/projects/:project_name/test_runs/:test_run_id" do
    if test_run.complete?
      show_page_key = TEST_RUN_SHOW_PAGE_CACHE_PREFIX + test_run.id

      if redis.exists(show_page_key)
        puts "EXISTS"
        redis.get(show_page_key)
      else
        puts "CREATING"
        show_page = haml :'projects/test_runs/show'
        redis.set(show_page_key, show_page)
        redis.expire(show_page_key, Hobson::Project::TestRun::MAX_AGE)
        show_page
      end
    else
      puts "NOT DONE"
      haml :'projects/test_runs/show'
    end
  end

  # delete
  delete "/projects/:project_name/test_runs/:test_run_id" do
    test_run.delete!
    redirect test_runs_path
  end

  # rerun
  post "/projects/:project_name/test_runs/:test_run_id/rerun" do
    redirect test_run_path test_run.rerun!
  end

  # abort
  post "/projects/:project_name/test_runs/:test_run_id/abort" do
    test_run.abort!
    redirect test_run_path
  end

  # project runtimes

  # show
  get "/projects/:project_name/test_runtimes" do |project_name|
    @test_runtimes = project.test_runtimes
    haml :'projects/test_runtimes'
  end

end
