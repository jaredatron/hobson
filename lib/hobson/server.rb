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

  def self.start! options={}
    Vegas::Runner.new(self, 'hobson', options)
  end

  def initialize app = nil
    super
    start_redis_slave!
  end

  def start_redis_slave!
    @redis_slave ||= begin
      @redis_slave = Redis::Slave.new(:master => Hobson.config[:redis])
      @redis_slave.start!
      raise "Failed to start Redis Slave" unless @redis_slave.process.alive?
      Hobson.root_redis = @redis_slave.balancer
      puts "started redis slave at #{@redis_slave.options[:slave].values_at(:host, :port).join(':')}"
    end
  end

  autoload :Partials, 'hobson/server/partials'
  autoload :Helpers,  'hobson/server/helpers'

  root = Pathname.new(File.expand_path('..', __FILE__)) + 'server'

  use Rack::MethodOverride

  set :protection,    :except => :frame_options
  set :views,         root + "views"
  set :public_folder, root + "public"
  set :static,        true

  # helpers ActionView::Helpers
  helpers Hobson::Server::Helpers
  helpers ActionView::Helpers::DateHelper

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

  get '/ci/check-for-changes' do
    project_refs = Hobson::CI::ProjectRef.all.find_all(&:needs_test_run?)
    project_refs.each(&:run_tests!)
    {:success => true, :changes => project_refs.size}.to_json
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
    @projects = Hobson::Project.all
    haml :'projects', :layout => !request.xhr?
  end

  get "/projects/:project_name" do |project_name|
    redirect "/projects/#{project_name}/test_runs"
  end

  get "/projects/:project_name/test_runs" do |project_name|
    @project   = Hobson::Project[project_name]
    @test_runs = @project.test_runs
    haml :'projects/test_runs', :layout => !request.xhr?
  end

  get "/projects/:project_name/test_runs/:id" do |project_name, id|
    @project  = Hobson::Project[project_name]
    @test_run = @project.test_runs(id)
    haml :'projects/test_runs/show', :layout => !request.xhr?
  end

  delete "/projects/:project_name/test_runs/:id" do |project_name, id|
    Hobson::Project[project_name].test_runs(id).delete!
    redirect "/projects/#{project_name}/test_runs"
  end

  post "/projects/:project_name/test_runs/:id/rerun" do |project_name, id|
    @project  = Hobson::Project[project_name]
    @test_run = @project.test_runs(id)
    @test_run = @project.run_tests!(@test_run.sha)
    redirect test_run_path
  end

  post "/projects/:project_name/test_runs/:id/abort" do |project_name, id|
    @test_run = Hobson::Project[project_name].test_runs(id)
    @test_run.abort!
    redirect test_run_path
  end

  get "/projects/:project_name/tests" do |project_name|
    @project  = Hobson::Project[project_name]
    @tests = @project.tests
    haml :'projects/tests', :layout => !request.xhr?
  end

end
