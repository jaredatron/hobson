require 'sinatra/base'
require 'vegas'
require 'haml'
require 'sass'

class Hobson::Server < Sinatra::Base

  def self.start! options={}
    Vegas::Runner.new Hobson::Server, 'hobson', options
  end

  autoload :Partials, 'hobson/server/partials'
  autoload :Helpers,  'hobson/server/helpers'

  root = Pathname.new(File.expand_path('..', __FILE__)) + 'server'

  use Rack::MethodOverride

  set :views,         root + "views"
  set :public_folder, root + "public"
  set :static,        true

  helpers Hobson::Server::Helpers

  get '/screen.css' do
    sass :screen
  end

  get "/" do
    redirect '/projects'
  end

  get "/projects" do
    @projects = Hobson::Project.all
    haml :'projects', :layout => !request.xhr?
  end

  # get "/projects/:project_name" do |project_name|
  #   @project   = Hobson::Project[project_name]
  # end

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
    redirect '/test_runs'
  end

end
