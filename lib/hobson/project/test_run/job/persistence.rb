require 'active_support/core_ext/hash/slice'

class Hobson::Project::TestRun::Job

  def prefix
    "job:#{index}:"
  end

  def data
    @data ||= test_run.data.keys.
      map{|key| key[/^#{prefix}(.*)$/, 1] }.compact.
      inject({}){ |data, key| data[key] = self[key]; data }
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
