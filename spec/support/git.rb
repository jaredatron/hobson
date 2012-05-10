module GitSupport

  def git *args
    context.git *args
  end

  def git_rev_parse rev
    git("rev-parse #{rev}").chomp
  end

end
