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

task :kill_processes, :roles => :workspaces do
  run "ps aux | grep -P 'cucumber|rspec|firefox|chrome|searchd|hobson' | grep -vE 'grep ' | awk '{print $2}' | xargs sudo kill -9"
end
