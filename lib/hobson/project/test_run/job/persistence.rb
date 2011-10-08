require 'active_support/core_ext/hash/slice'

class Hobson::Project::TestRun::Job

  def prefix
    "job:#{index}:"
  end

  def data
    test_run.data.inject({}){ |data, (key, value)|
      key.match(/^#{prefix}(.*)$/) ? data.update($1 => value) : data
    }
  end

  def [] key
    test_run["#{prefix}#{key}"]
  end

  def []= key, value
    test_run["#{prefix}#{key}"] = value
  end

  def keys
    data.keys
  end

end
