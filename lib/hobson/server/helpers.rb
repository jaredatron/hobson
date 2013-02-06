# encoding: UTF-8
module Hobson::Server::Helpers

  include Rack::Utils
  alias_method :h, :escape_html

  def haml layout, options={}
    options[:layout] ||= !request.xhr?
    super layout, options
  end

  def projects
    @projects ||= Hobson.projects
  end

  def project_name
    @project_name ||= params["project_name"]
  end

  def project
    @project ||= Hobson::Project.find(project_name) or raise Sinatra::NotFound
  end

  def test_runs
    @test_runs ||= project.test_runs
  end

  def test_run_id
    @test_run_id ||= params["test_run_id"]
  end

  def test_run
    @test_run ||= project.test_runs(test_run_id) or raise Sinatra::NotFound
  end

  def project_refs
    @project_refs ||= Hobson::CI.project_refs
  end

  def project_ref_id
    @project_ref_id ||= "#{params["project_name"]}:#{params["ref"]}"
  end

  def project_ref
    @project_ref ||= Hobson::CI::ProjectRef.find(project_ref_id)
  end

  # URL Helpers

  def projects_path
    "/projects"
  end

  def new_project_path
    "#{projects_path}/new"
  end

  def distance_of_time_in_minutes seconds
    "#{((seconds || 0) / 60).round(2)} minutes"
  end

  # project_path(project)
  # project_path('project_name')
  def project_path project_name=self.project_name
    project_name = project_name.name if project_name.is_a? Hobson::Project
    "#{projects_path}/#{project_name}"
  end

  def edit_project_path project_name=self.project_name
    "#{project_path(project_name)}/edit"
  end

  def test_runs_path project_name=self.project_name
    "#{project_path(project_name)}/test_runs"
  end

  def new_test_run_path project_name=self.project_name
    "#{test_runs_path(project_name)}/new"
  end

  def test_run_path test_run_id=self.test_run_id, project_name=self.project_name
    if test_run_id.is_a? Hobson::Project::TestRun
      test_run_id, project_name = test_run_id.id, test_run_id.project.name
    end
    "#{test_runs_path(project_name)}/#{test_run_id}"
  end

  def test_runtimes_path project_name=self.project_name
    "#{project_path(project_name)}/test_runtimes"
  end

  def flaky_tests_path project_name=self.project_name
    "#{project_path(project_name)}/flaky_tests"
  end

  def ci_path
    '/ci'
  end

  def project_refs_path
    "#{ci_path}/project_refs"
  end

  def new_project_ref_path
    "#{project_refs_path}/new"
  end

  def project_ref_path project_ref=self.project_ref
    "#{project_refs_path}/#{project_ref.project_name}/#{project_ref.ref}"
  end

  def project_ref_run_tests_path project_ref=self.project_ref
    "#{project_ref_path(project_ref)}/run_tests"
  end

  def repo_url origin
    host, path = origin.scan(/(?:https?:\/\/)?(?:.*@)?(.+?)[:\/]+(.+?)(?:\.git)?$/).first
    "http://#{host}/#{path}"
  end

  def sha_url origin, sha
    "#{repo_url(origin)}/commit/#{sha}"
  end

  def ref_url origin, ref
    "#{repo_url(origin)}/tree/#{ref}"
  end

  def redis
    @redis ||= Redis::Namespace.new(:server, :redis => Hobson.redis)
  end

  def body_classnames
    @body_classnames ||= []
  end

  def auto_refresh!
    body_classnames << :auto_refresh
  end

  def page_title page_title=nil
    @page_title = page_title unless page_title.nil?
    @page_title
  end

  def now
    @now ||= Time.now
  end

  def states
    Hobson::Project::TestRun::Job::STATES
  end

  def classname string
    string.to_s.gsub(/[ _]/,'-')
  end

  def step_classname object
    "step-#{classname(object.step)}"
  end

  def est_test_run_duration
    @est_test_run_duration ||= test_run.jobs.map{|j| j.est_runtime || 0}.sort.last
    @est_test_run_duration ||= 0
  end

  def test_run_duration
    @test_run_duration ||= (test_run.complete_at || now) - (test_run.started_at || now)
    @test_run_duration ||= 0
  end

  def job_timeline_duration
    @job_timeline_duration ||= (test_run.complete_at || now) - (test_run.enqueued_jobs_at || now)
    @job_timeline_duration ||= 0
  end

  def progress
    # value, max = @test_run.complete? ? [1,1] : [test_run_duration, est_test_run_duration]
    # title = "#{distance_of_time_in_words(value)} / #{distance_of_time_in_words(max)}"
    haml_tag '.progress' do
      # haml_tag :progress, :value => value, :max => max, :title => title
    end
  end

  def tests_completed
    value, max = test_run.tests.find_all(&:complete?).count, test_run.tests.count
    haml_tag :progress, :value => value, :max => max, :title => "#{value}/#{max}", :class => 'tests-completed'
  end

  def job_timeline job
    last_percentage = 0

    # collect all the from times for each landmark and filter our any unused landmarks
    # [[:created, 2012-05-16 18:29:24 -0700], [:enqueued, 2012-05-16 18:29:24 -0700], …]
    events = job.landmarks.
      map{|landmark| [landmark, job.send(:"#{landmark}_at")] }.
      reject{|l| l.last.nil? }.sort_by(&:last)

    # collect the to for each landmark from its following landmark
    # [[:created, 2012-05-16 18:29:24 -0700, 2012-05-16 18:29:24 -0700], [:enqueued, 2012-05-16 18:29:24 -0700, 2012-05-16 18:29:33 -0700], …]
    events.each_with_index{|event, index|
      event << events[index+1].try(:[],1)
    }

    # inject some html
    events.each{|(name, from, to)|
      next if name == job.landmarks.last
      to ||= now
      duration = to - from
      left  = ((from - test_run.enqueued_jobs_at) / job_timeline_duration) * 100
      right = ((((to - test_run.enqueued_jobs_at) / job_timeline_duration) * 100) - 100) * -1
      html_options = {}
      html_options[:title] = "#{name} for #{distance_of_time_in_minutes(duration)}"
      html_options[:class] = "landmark-#{classname(name)}"
      html_options[:style] = "left: #{left}%; right: #{right}%;"
      haml_tag(:li, html_options[:title], html_options)
    }
  end

  def action_button name, action, method = :post
    delete = method == :delete
    method = :post if delete
    haml_tag :form, :action => action, :method => method do
      haml_tag :input, :type => :hidden, :name => :_method, :value => :delete if delete
      haml_tag :input, :type => :submit, :value => name
    end
  end

  def sort_tests tests
    tests.sort_by{|test|
      status = case test.status.to_sym
        when :running  ; 1
        when :complete ; test.pass? ? 3 : 0
        when :waiting  ; 2
        else 4
      end
      [status, test.job || -1]
    }
  end

  def test_run_status_classname test_run_status
    case test_run_status
    when 'passed'
      'pass'
    when 'errored','aborted','failed'
      'fail'
    when 'complete','running tests','waiting to be run','building','waiting to be built','waiting...'
      'building'
    else
      'nil'
    end
  end

  def test_run_status_icon test_run, &block
    if test_run.nil?
      haml_tag(:div, :class => 'icon', &block)
    else
      haml_tag(:a, :class => 'icon', :href => test_run_path(test_run), :title => test_run.id, &block)
    end
  end

end
