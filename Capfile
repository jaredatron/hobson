require "rvm/capistrano"

INSTANCES = %w[
  ec2-184-73-185-51.compute-1.amazonaws.com
  ec2-174-129-87-249.compute-1.amazonaws.com
  ec2-174-129-137-32.compute-1.amazonaws.com
  ec2-23-20-95-13.compute-1.amazonaws.com
  ec2-23-20-123-107.compute-1.amazonaws.com
  ec2-184-72-166-179.compute-1.amazonaws.com
  ec2-23-20-9-246.compute-1.amazonaws.com
  ec2-184-73-24-209.compute-1.amazonaws.com
  ec2-23-20-146-206.compute-1.amazonaws.com
  ec2-23-20-219-206.compute-1.amazonaws.com
  ec2-50-17-115-219.compute-1.amazonaws.com
  ec2-204-236-255-89.compute-1.amazonaws.com
  ec2-184-72-165-139.compute-1.amazonaws.com
  ec2-23-20-53-116.compute-1.amazonaws.com
  ec2-50-16-63-50.compute-1.amazonaws.com
  ec2-23-20-195-14.compute-1.amazonaws.com
  ec2-23-20-214-168.compute-1.amazonaws.com
  ec2-184-73-120-68.compute-1.amazonaws.com
  ec2-184-72-208-156.compute-1.amazonaws.com
  ec2-50-16-9-133.compute-1.amazonaws.com
]

role :workspaces, *INSTANCES

set :rvm_ruby_string, '1.9.3-p0'

task :list_redis, :roles => :workspaces do
  run "ps aux | grep -iP 'redis-server' | grep -vE 'grep '"
end

task :kill_test_processes, :roles => :workspaces do
  run "ps aux | grep -iP 'cucumber|rspec|firefox|chrome|searchd' | grep -vE 'grep |redis' | awk '{print $2}' | xargs sudo kill -9"
end

task :bundle, :roles => :workspaces do
  run "cd /home/change/hobson; bundle"
end

task :git_pull, :roles => :workspaces do
  run "cd /home/change/hobson; git pull"
end

task :restart, :roles => :workspaces do
  run 'sudo monit restart hobson'
end

task :stop, :roles => :workspaces do
  run 'sudo monit stop hobson'
end

task :start, :roles => :workspaces do
  run 'sudo monit start hobson'
end

task :hobson_restart, :roles => :workspaces do
  run '/etc/init.d/hobson restart'
end

task :hobson_stop, :roles => :workspaces do
  run '/etc/init.d/hobson stop'
end

task :hobson_start, :roles => :workspaces do
  run '/etc/init.d/hobson start'
end

task :restart_web, :hosts => INSTANCES.first do
  run "#{hobson('web --kill')} && ${hobson('web -p 5678')}"
end

task :kill_webs, :hosts => INSTANCES.first do
  run "#{hobson('web --kill')} && ${hobson('resque-web --kill')}"
end

def hobson cmd
  %{(cd ~/hobson_workspace && ~/hobson/bin/hobson #{cmd})}
end

task :summary, :roles => :workspaces do
  run "sudo monit summary"
end
