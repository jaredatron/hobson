module Hobson::Server::Helpers

  include Rack::Utils
  include Hobson::Server::Partials

  alias_method :h, :escape_html

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
      html_options[:title] = "#{landmark} for #{duration.to_i} seconds"
      html_options[:class] = "landmark-#{classname(landmark)}"
      html_options[:style] = "left: #{left}%; right: #{right}%;"
      haml_tag(:li, html_options[:title], html_options)
    end
  end

end
