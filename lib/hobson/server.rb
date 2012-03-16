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
    @project_refs = Hobson::CI::ProjectRef.all
    if @project_refs.present?
      haml :ci, :layout => !request.xhr?
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
      project_refs = Hobson::CI::ProjectRef.all.find_all(&:needs_test_run?)
      project_refs.each(&:run_tests!)
      response[:checked] = true
    end
    response.to_json
  end

  get "/ci/new" do
    haml :'ci/new'
  end

  post "/ci/new" do
    origin_url, ref = params.values_at("origin_url", "ref")
    origin_url.gsub!('&#x2F;','/') # I have no idea why i need this now
    project_ref = Hobson::CI::ProjectRef.new(origin_url, ref)
    project_ref.save
    project_ref.run_tests! if project_ref.needs_test_run?
    redirect '/ci'
  end

  delete "/ci/new" do
    Hobson::CI::ProjectRef.new(params).delete
    redirect '/ci'
  end

  get "/projects" do
    @projects = Hobson.projects
    haml :'projects', :layout => !request.xhr?
  end

  get "/projects/:project_name" do
    redirect test_runs_path
  end

  get "/projects/:project_name/test_runs" do
    haml :'projects/test_runs', :layout => !request.xhr?
  end

  get "/projects/:project_name/test_runs/:test_run_id" do
    haml :'projects/test_runs/show', :layout => !request.xhr?
  end

  delete "/projects/:project_name/test_runs/:test_run_id" do
    test_run.delete!
    redirect test_runs_path
  end

  post "/projects/:project_name/test_runs/:test_run_id/rerun" do
    @test_run = project.run_tests!(test_run.sha)
    redirect test_run_path
  end

  post "/projects/:project_name/test_runs/:test_run_id/abort" do
    test_run.abort!
    redirect test_run_path
  end

  get "/projects/:project_name/tests" do |project_name|
    @tests = project.tests
    haml :'projects/tests', :layout => !request.xhr?
  end

end
