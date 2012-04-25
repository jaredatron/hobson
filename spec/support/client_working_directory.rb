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
    git("config --get remote.origin.url").chomp.should == ExampleProject::ORIGIN
    git "reset --hard origin/master"
    git "clean -df"
    write_config! DEFAULT_CONFIG
  end

  def current_sha
    git("rev-parse HEAD").chomp
  end

  def git cmd
    sh "git clone #{ExampleProject::ORIGIN} #{path}" unless path.exist?
    sh %[cd "#{path}" && git --git-dir="#{path+'.git'}" #{cmd}]
  end

end
