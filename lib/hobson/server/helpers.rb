module Hobson::Server::Helpers

  include Rack::Utils
  include Hobson::Server::Partials

  alias_method :h, :escape_html

  # URL Helpers

  def project_path project=@project
    "/projects/#{project.name}"
  end

  def test_run_path test_run=@test_run
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

  def test_run
    @test_run
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
    test_run.jobs.map{|j| j.est_runtime || 0}.sort.last
  end

  def test_run_duration
    @test_run_duration ||= (test_run.complete_at || now) - (test_run.started_at || now)
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

end
