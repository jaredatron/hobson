class Hobson::Worker < Resque::Worker

  def initialize
    @parent_pid = $$
    super '*'
  end

  def parent?
    $$ == @parent_pid
  end

  def child?
    !parent?
  end

  def proc_name
    parent? ? "Hobson Worker (#{Hobson.git_version[0..8]})" : "Hobson Test Runner for #{@parent_pid}"
  end

  def procline(string)
    $0 = "#{proc_name}: #{string}"
    log! $0
  end

end
