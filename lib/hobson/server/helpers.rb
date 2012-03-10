module Hobson::Server::Helpers

  include Rack::Utils
  alias_method :h, :escape_html

  def project
    @project ||= Hobson::Project[params["project_name"]]
  end

  def test_runs
    @test_runs ||= project.test_runs
  end

  def test_run
    @test_run ||= project.test_runs(params["test_run_id"]) or raise Sinatra::NotFound
  end

  # URL Helpers

  def project_path project=self.project
    "/projects/#{project.name}"
  end

  def test_runs_path project=self.project
    "/projects/#{project.name}/test_runs"
  end

  def test_run_path test_run=self.test_run
    "/projects/#{test_run.project.name}/test_runs/#{test_run.id}"
  end

  def repo_url origin_url
    host, path = origin_url.scan(/(?:https?:\/\/)?(?:.*@)?(.+?)[:\/]+(.+?)(?:\.git)?$/).first
    "http://#{host}/#{path}"
  end

  def sha_url origin_url, sha
    "#{repo_url(origin_url)}/commit/#{sha}"
  end

  def ref_url origin_url, ref
    "#{repo_url(origin_url)}/tree/#{ref}"
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

  def progress
    value, max = @test_run.complete? ? [1,1] : [test_run_duration, est_test_run_duration]
    title = "#{distance_of_time_in_words(value)} / #{distance_of_time_in_words(max)}"
    haml_tag '.progress' do
      haml_tag :progress, :value => value, :max => max, :title => title
    end
  end

  def tests_completed
    value, max = test_run.tests.find_all(&:complete?).count, test_run.tests.count
    haml_tag '.tests-completed' do
      haml_tag :progress, :value => value, :max => max, :title => "#{value}/#{max}"
    end
  end

  def job_timeline job
    last_percentage = 0
    job.landmarks.map do |landmark|
      from = job.send(:"#{landmark}_at")
      next unless from.present?
      next_landmark = job.landmarks[job.landmarks.index(landmark)+1]
      next unless next_landmark.present?
      to = job.send(:"#{next_landmark}_at") || test_run.complete_at || now

      duration = to - from
      # percentage = (duration / test_run_duration) * 100
      left  = ((from - test_run.started_at) / test_run_duration) * 100
      right = ((((to - test_run.started_at) / test_run_duration) * 100) - 100) * -1

      html_options = {}
      html_options[:title] = "#{landmark} for #{distance_of_time_in_words(duration.to_i)}"
      html_options[:class] = "landmark-#{classname(landmark)}"
      html_options[:style] = "left: #{left}%; right: #{right}%;"
      haml_tag(:li, html_options[:title], html_options)
    end
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
        when :running  ; 0
        when :complete ; test.pass? ? 2 : 1
        when :waiting  ; 3
        else 4
      end
      [status, test.job || -1]
    }
  end


  # Sam Elliott’s partials.rb
  # https://gist.github.com/119874
  def partial(template, *args)
    template_array = template.to_s.split('/')
    template = template_array[0..-2].join('/') + "/_#{template_array[-1]}"
    options = args.last.is_a?(Hash) ? args.pop : {}
    options.merge!(:layout => false)
    if collection = options.delete(:collection) then
      collection.inject([]) do |buffer, member|
        buffer << haml(:"#{template}", options.merge(:layout =>
        false, :locals => {template_array[-1].to_sym => member}))
      end.join("\n")
    else
      haml(:"#{template}", options)
    end
  end

end
