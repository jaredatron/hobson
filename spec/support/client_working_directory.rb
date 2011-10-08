require File.expand_path('../working_directory', __FILE__ )

module ClientWorkingDirectory

  extend WorkingDirectory
  extend self

  def path
    TMP + 'client_working_directory'
  end

  def config_path
    path + 'config/hobson.yml'
  end

  def reset!
    sh "git clone #{ExampleProject::GIT_URL} #{path}" unless path.exist?
    write_config! DEFAULT_CONFIG
  end

  def current_sha
    sh("git rev-parse HEAD").chomp
  end

end
