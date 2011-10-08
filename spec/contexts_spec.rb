require 'spec_helper'

describe 'contexts' do

  client_context do

    it "should be in client context" do
      `pwd`.chomp.should == ClientWorkingDirectory.path.to_s
      `git config --get remote.origin.url`.chomp.should == ExampleProject::GIT_URL
    end

  end

  worker_context do

    it "should be in worker context" do
      `pwd`.chomp.should == WorkerWorkingDirectory.path.to_s
      `cd "#{WorkerWorkingDirectory.example_project_path}" && git config --get remote.origin.url`.chomp.should == ExampleProject::GIT_URL
    end

  end

end
