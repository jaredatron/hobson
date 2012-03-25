require 'sinatra/base'
require 'vegas'
require 'haml'
require 'sass'

require "active_support/dependencies/autoload"

require 'action_view/helpers/capture_helper'
require 'action_view/helpers/date_helper'

# lolz
I18n.load_path << $:.map{|path| File.join(path,'action_view/locale/en.yml') }.find{|path| File.exist?(path) }

class Hobson::Server < Sinatra::Base

  # patch Vegas::Runner to start a redis slave if the server needs to be started
  # but before it forks
  class Runner < Vegas::Runner
    def check_for_running path=nil
      super
      Hobson.use_redis_slave! unless ENV['HOBSON_REDIS_SLAVE'] == 'false'
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
    redirect '/ci'
  end

  get '/ci' do
    if project_refs.present?
      haml :ci
    else
      redirect '/ci/new'
    end
  end

  MAX_CHECK_FOR_CHANGES_INTERVAL = 60 # seconds
  get '/ci/check-for-changes' do
    now = Time.now
    @@last_time_we_checked_for_changes ||= now - MAX_CHECK_FOR_CHANGES_INTERVAL
    seconds_since_last_check = now - @@last_time_we_checked_for_changes
    response = {:success => true, :seconds_since_last_check => seconds_since_last_check, :checked => false}
    if seconds_since_last_check >= MAX_CHECK_FOR_CHANGES_INTERVAL
      @@last_time_we_checked_for_changes = now
      project_refs.each(&:check_for_new_sha!)
      response[:checked] = true
    end
    response.to_json
  end

  # ci

  get "/ci/new" do
    haml :'ci/new'
  end

  post "/ci/new" do
    project_name, ref = params['project_ref'].values_at("project_name", "ref")
    Hobson::CI::ProjectRef.create(project_name, ref)
    redirect '/ci'
  end

  delete "/ci/new" do
    Hobson::CI::ProjectRef.new(params).delete
    redirect '/ci'
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

    redirect project_path
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
    @test_run = project.run_tests!(test_run['sha'], test_run['requestor'])
    redirect test_run_path
  end

  # show
  get "/projects/:project_name/test_runs/:test_run_id" do
    haml :'projects/test_runs/show'
  end

  # delete
  delete "/projects/:project_name/test_runs/:test_run_id" do
    test_run.delete!
    redirect test_runs_path
  end

  # rerun
  post "/projects/:project_name/test_runs/:test_run_id/rerun" do
    @test_run = project.run_tests!(test_run.sha)
    redirect test_run_path
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
