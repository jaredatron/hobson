module WorkingDirectory

  # ROOT     = ::ROOT + 'tmp/hobson'
  # PROJECTS = WorkerHobsonDir::ROOT + 'projects'

  # EXAMPLE_PROJECT_NAME    = 'example_hobson_project'
  # EXAMPLE_PROJECT_GIT_URL = 'git://github.com/deadlyicon/example_hobson_project.git'
  # EXAMPLE_PROJECT         = PROJECTS + EXAMPLE_PROJECT_NAME

  # def reset!
  #   PROJECTS.mkpath
  #   checkout_example_project!
  #   git "reset --hard origin/master"
  #   git "clean -df"
  # end

  # def current_sha
  #   git("rev-parse HEAD").chomp
  # end

  # private

  # def checkout_example_project!
  #   return if EXAMPLE_PROJECT.exist?
  #   sh <<-SH
  #     cd "#{PROJECTS}" &&
  #     git clone "#{EXAMPLE_PROJECT_GIT_URL}"
  #   SH
  # end

  # def git git_cmd
  #   # ENV['GIT_WORK_TREE'] = EXAMPLE_PROJECT_ROOT
  #   # ENV['GIT_DIR']       = EXAMPLE_PROJECT_ROOT + 'git'
  #   sh <<-SH
  #     export GIT_WORK_TREE="#{EXAMPLE_PROJECT}" &&
  #     cd "#{EXAMPLE_PROJECT}" &&
  #     git #{git_cmd}
  #   SH
  # end

  def sh cmd
    output = `#{cmd} 2>/dev/null` or raise "failed to run #{cmd.inspect}"
  end

  def write_config! config
    config_path.open('w'){|file| file.write config.to_yaml }
  end

end
