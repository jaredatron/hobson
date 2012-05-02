require "rvm/capistrano"


# ec2-23-20-146-206.compute-1.amazonaws.com
# ip-10-124-202-113.ec2.internal

# ec2-184-73-120-68.compute-1.amazonaws.com
# ip-10-123-30-170.ec2.internal

# ec2-23-20-214-168.compute-1.amazonaws.com
# ip-10-124-90-12.ec2.internal

# ec2-23-20-195-14.compute-1.amazonaws.com
# ip-10-122-163-21.ec2.internal

# ec2-50-16-63-50.compute-1.amazonaws.com
# ip-10-124-79-40.ec2.internal

# ec2-23-20-53-116.compute-1.amazonaws.com
# ip-10-88-219-220.ec2.internal

# ec2-184-72-165-139.compute-1.amazonaws.com
# ip-10-124-147-188.ec2.internal

# ec2-204-236-255-89.compute-1.amazonaws.com
# ip-10-88-233-156.ec2.internal

# ec2-50-17-115-219.compute-1.amazonaws.com
# domU-12-31-38-04-81-91.compute-1.internal

# ec2-184-72-208-156.compute-1.amazonaws.com
# domU-12-31-38-01-C9-02.compute-1.internal

# ec2-50-16-9-133.compute-1.amazonaws.com
# ip-10-90-135-246.ec2.internal

# ec2-184-73-24-209.compute-1.amazonaws.com
# domU-12-31-38-07-05-E6.compute-1.internal

# ec2-23-20-9-246.compute-1.amazonaws.com
# ip-10-124-137-136.ec2.internal

# ec2-184-72-166-179.compute-1.amazonaws.com
# ip-10-124-219-219.ec2.internal

# ec2-23-20-123-107.compute-1.amazonaws.com
# ip-10-126-35-19.ec2.internal

# ec2-23-20-95-13.compute-1.amazonaws.com
# ip-10-86-178-180.ec2.internal

# ec2-174-129-137-32.compute-1.amazonaws.com
# ip-10-123-11-173.ec2.internal

# ec2-174-129-87-249.compute-1.amazonaws.com
# ip-10-86-210-126.ec2.internal

# ec2-23-20-219-206.compute-1.amazonaws.com
# ip-10-87-14-108.ec2.internal

# ec2-184-73-185-51.compute-1.amazonaws.com
# ip-10-123-14-62.ec2.internal

MAP = {
  'ip-10-124-202-113.ec2.internal' => 'ec2-23-20-146-206.compute-1.amazonaws.com',
  'ip-10-123-30-170.ec2.internal' => 'ec2-184-73-120-68.compute-1.amazonaws.com',
  'ip-10-124-90-12.ec2.internal' => 'ec2-23-20-214-168.compute-1.amazonaws.com',
  'ip-10-122-163-21.ec2.internal' => 'ec2-23-20-195-14.compute-1.amazonaws.com',
  'ip-10-124-79-40.ec2.internal' => 'ec2-50-16-63-50.compute-1.amazonaws.com',
  'ip-10-88-219-220.ec2.internal' => 'ec2-23-20-53-116.compute-1.amazonaws.com',
  'ip-10-124-147-188.ec2.internal' => 'ec2-184-72-165-139.compute-1.amazonaws.com',
  'ip-10-88-233-156.ec2.internal' => 'ec2-204-236-255-89.compute-1.amazonaws.com',
  'domU-12-31-38-04-81-91.compute-1.internal' => 'ec2-50-17-115-219.compute-1.amazonaws.com',
  'domU-12-31-38-01-C9-02.compute-1.internal' => 'ec2-184-72-208-156.compute-1.amazonaws.com',
  'ip-10-90-135-246.ec2.internal' => 'ec2-50-16-9-133.compute-1.amazonaws.com',
  'domU-12-31-38-07-05-E6.compute-1.internal' => 'ec2-184-73-24-209.compute-1.amazonaws.com',
  'ip-10-124-137-136.ec2.internal' => 'ec2-23-20-9-246.compute-1.amazonaws.com',
  'ip-10-124-219-219.ec2.internal' => 'ec2-184-72-166-179.compute-1.amazonaws.com',
  'ip-10-126-35-19.ec2.internal' => 'ec2-23-20-123-107.compute-1.amazonaws.com',
  'ip-10-86-178-180.ec2.internal' => 'ec2-23-20-95-13.compute-1.amazonaws.com',
  'ip-10-123-11-173.ec2.internal' => 'ec2-174-129-137-32.compute-1.amazonaws.com',
  'ip-10-86-210-126.ec2.internal' => 'ec2-174-129-87-249.compute-1.amazonaws.com',
  'ip-10-87-14-108.ec2.internal' => 'ec2-23-20-219-206.compute-1.amazonaws.com',
  'ip-10-123-14-62.ec2.internal' => 'ec2-184-73-185-51.compute-1.amazonaws.com',
}

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

BROKEN = %w[
  ec2-50-16-9-133.compute-1.amazonaws.com
]

role :workspaces, *INSTANCES

role :broken, *BROKEN

set :rvm_ruby_string, '1.9.3-p0'

task :list_redis, :roles => :workspaces do
  run "ps aux | grep -iP 'redis-server' | grep -vE 'grep '"
end

task :kill_test_processes, :roles => :broken do
  run "ps aux | grep -iP 'cucumber|rspec|firefox|chrome|searchd' | grep -vE 'grep |redis' | awk '{print $2}' | xargs sudo kill -9"
end

task :bundle, :roles => :workspaces do
  run "cd /home/change/hobson; bundle"
end

task :git_pull, :roles => :workspaces do
  run "eval `ssh-agent`; ssh-add ~/.ssh/hobson_ec2_change; cd /home/change/hobson; git pull"
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

task :restart_webs, :hosts => INSTANCES.first do
  run "#{hobson('web --kill')} && #{hobson('resque-web --kill')}"
  run "#{hobson('resque-web -p 5679')} && #{hobson('web -p 5678')}"
end

task :summary, :roles => :workspaces do
  run "sudo monit summary"
end

def hobson cmd
  %{(cd ~/hobson_workspace && ~/hobson/bin/hobson #{cmd})}
end

def internal_to_external internal_hostnames
  internal_hostnames.inject([]){|external_hostnames, hostname| external_hostnames << MAP[hostname] if MAP[hostname]}
end
