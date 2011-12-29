class Hobson::CI::ProjectRef

  def self.all
    Hobson::CI.data.keys.map{|key| self.new *key.split('::') }
  end

  delegate :data, :to => Hobson::CI

  attr_reader :origin_url, :ref

  def initialize origin_url, ref=nil
    @origin_url, @ref = origin_url, ref || 'master'
  end

  def key
    "#{origin_url}::#{ref}"
  end

  # def save
  #   data[key] ||= current_sha
  # end

  def delete
    data.delete key
  end

  def project
    @project ||= Hobson::Project.from_origin_url(origin_url)
  end

  def last_test_run
    @last_test_run ||= project \
      .test_runs \
      .find_all{|test_run| test_run.sha == last_sha} \
      .sort_by(&:enqueued_build_at) \
      .last
  end

  def last_sha
    data[key]
  end

  def current_sha
    @current_sha ||= begin
      cmd    = %(git ls-remote #{origin_url.inspect} #{ref.inspect})
      result = `#{cmd}`
      raise "failed getting remote sha for #{origin_url.inspect} #{ref.inspect}\n#{cmd.inspect} failed" unless $?.success?
      result.scan(/^(\w+)/).try(:first).try(:first)
    end
  end

  def needs_test_run?
    last_sha != current_sha && project.test_runs.map(&:sha).exclude?(current_sha)
  end

  def run_tests!
    @last_test_run = project.run_tests!(current_sha) and data[key] = current_sha
  end

  def running?
    last_test_run && !last_test_run.complete?
  end

  def passed?
    last_test_run && last_test_run.passed?
  end

  def failed?
    last_test_run && !passed?
  end

  def status
    running? ? 'running' :
    passed?  ? 'passed'    :
    failed?  ? 'failed'    :
    'new'
  end

end
