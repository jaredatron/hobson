class Hobson::Project::TestRun::Job

  def file_namespace
    @file_namespace ||= Pathname.new("/testruns/#{test_run.id}/jobs/#{index}")
  end

  def artifacts
    data.inject({}){ |data, (key, value)|
      key.match(/^artifact:(.*)$/) ? data.update($1 => value) : data
    }
  end

  def save_artifact path, options={}
    path = workspace.root.join(path.to_s)
    name = options.delete(:name) || (path.relative? ? path.basename : path.relative_path_from(workspace.root) )
    options[:key] = key_from_name(name)
    options[:content_type] ||= 'text/plain'
    options[:body] ||= path.read
    options[:public] = true unless options.has_key?(:public)
    file = Hobson.files.create(options)
    public_url = if Hobson.config[:storage][:provider] =~ /\Aaws\z/i
      CGI::unescape(public_url_from_file(file))
    else
      'file://' + File.join(
        Hobson.files.directory.connection.local_root,
        Hobson.files.directory.key,
        file.key
      ) rescue ""
    end
    self["artifact:#{name}"] = public_url
    logger.info "saving artifact #{name} -> #{public_url}"
    file
  end

  def get_artifact name
    Hobson.files.get key_from_name(name)
  end

  private

  def key_from_name name
    File.join(file_namespace,name).to_s[1..-1]
  end

  # Avoid hitting AWS for public_url
  # There are intermittent problems with requesting the public_url immediately after creating the file
  def public_url_from_file file
    directory_key = Hobson.files.directory.key
    file_key = file.key
    if directory_key.to_s =~ /^(?:[a-z]|\d(?!\d{0,2}(?:\.\d{1,3}){3}$))(?:[a-z0-9]|\.(?![\.\-])|\-(?![\.])){1,61}[a-z0-9]$/
      "https://#{directory_key}.s3.amazonaws.com/#{Fog::AWS.escape(file_key)}"
    else
      "https://s3.amazonaws.com/#{directory_key}/#{Fog::AWS.escape(file_key)}"
    end
  end

end
