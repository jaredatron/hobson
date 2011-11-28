class Hobson::Project::TestRun::Job

  def artifacts
    data.inject({}){ |data, (key, value)|
      key.match(/^artifact:(.*)$/) ? data.update($1 => value) : data
    }
  end

  def save_artifact path, name=nil
    path = workspace.root.join(path.to_s)
    warn "unable to save artifact #{path}. it isnt a file" and return false unless path.file?
    name ||= path.relative? ? path.relative_path_from(workspace.root) : path.basename
    file = save_file(s3_namespace.join(name).sub(%r{^/}, ''), path.read)
    self["artifact:#{name}"] = file.public_link
    logger.info "saving artifact #{name} -> #{file.public_link}"
    file
  end

  protected

  def s3_namespace
    Pathname.new("/testruns/#{test_run.id}/jobs/#{index}")
  end

  def files
    path = s3_namespace.sub(%r{^/}, '')
    Hobson.s3_bucket.keys.find_all{|key| key.name.match(%r[^#{path}]) }
  end

  def save_file name, content
    file = RightAws::S3::Key.create(Hobson.s3_bucket, name.to_s, content)
    file.put(content, 'public-read', {})
    file
  end

end
