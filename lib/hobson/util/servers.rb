require 'hobson'
require 'fog'

module Hobson
  module Servers
    extend self

    def startup!(n)
      n.times do
        fog.servers.create(
          image_id: 'ami-0157c268',
          flavor_id: 'm1.large',
          key_name: 'change',
          groups: ['change_ci'],
          tags: {"Name" => "Hobson Worker"},
          user_data: STARTUP_SCRIPT,
        )
      end
    end

    def shutdown!
      stop_all_workers!
      wait_for_workers_to_finish!
      terminate_all_instances!
    end

    def audit_workers!
      servers_and_workers.each do |server, worker_id|
        pid = worker_id.split(':')[1]
        unless server.ssh("kill -0 #{pid}").first.status == 0
          print "Cleaning stale worker #{worker_id}..."
          cleanup_old_worker! worker_id
          puts 'done!'
        end
      end
    end

    def pause!
      servers_and_workers.each do |server, worker_id|
        pid = worker_id.split(':')[1]
        server.ssh("kill -s USR2 #{pid}")
      end
    end

    def quit!
      servers_and_workers.each do |server, worker_id|
        pid = worker_id.split(':')[1]
        server.ssh("kill -s QUIT #{pid}")
      end
    end

    def continue!
      servers_and_workers.each do |server, worker_id|
        pid = worker_id.split(':')[1]
        server.ssh("kill -s CONT #{pid}")
      end
    end

    def hobson_servers
      @hobson_servers ||= fog.servers.select { |s|
          s.state == 'running' && (n = s.tags["Name"]) =~ /hobson/i && n !~ /master/i
        }.each { |s|
          s.username = 'change'
          s.private_key = PRIVATE_KEY
        }
    end

    private

    def stop_all_workers!
      puts "Sending quit to all workers..."
      servers_and_workers.each do |server, worker|
        pid = worker.id.split(':')[1]
        server.ssh("sudo monit unmonitor hobson && kill -s QUIT #{pid}")
      end
    end

    def wait_for_workers_to_finish!
      print "Waiting for workers to finish..."
      loop do
        break if Hobson.resque.workers.empty?
        sleep 5
        print '.'
      end
      puts
    end

    def terminate_all_instances!
      puts "Terminating all instances..."
      hobson_servers.each(&:destroy)
    end

    def fog
      @fog ||= Fog::Compute.new(
          provider: 'AWS',
          aws_access_key_id: 'AKIAI6MGGNYJEPGAGD3Q',
          aws_secret_access_key: '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',
        )
    end

    def servers_and_workers
      @servers_and_workers ||= Hobson.resque.workers.inject([]) do |result, worker|
        hostname = worker.id.split(':').first
        result << [hobson_servers.select { |s| s.private_dns_name =~ /#{hostname}/ }.first, worker]
      end
    end

    # Removes redis keys for a nonexistent worker
    def cleanup_old_worker! worker_id
      Hobson.resque.redis.del "worker:#{worker_id}"
      Hobson.resque.redis.del "worker:#{worker_id}:started"
      Hobson.resque.redis.del "stat:processed:#{worker_id}"
      Hobson.resque.redis.del "stat:failed:#{worker_id}"
      Hobson.resque.redis.srem 'workers', worker_id
    end

    PRIVATE_KEY = <<-EOF.gsub(/^\s+/, '')
      -----BEGIN RSA PRIVATE KEY-----
      MIICXgIBAAKBgQC9LBPMOtIGTTMNtgiz93gZ9b5dCjWpEaKPFHIjNSnOLGr0OVr3
      /HP1R/3t23/k3U0RUcwUp242ogdH8L7CAgjw4heoCEnwugzl6T18/65c6aU1BSBO
      HDkDkNULRQowuLvjnSdEIKZBBFGTQDrU2sgR5Nczv45cqtk35Lb2F/ipsQIDAQAB
      AoGBALgkGblpYFvF9fZYxav5Li2G6qDCeW1zvxsrudbPvzv0PMAyvHw8f9u5ElLg
      oWP0jzpWtyM7v6rqmc/LZsSPGodD/cqWVvyEOEBOztK6k8rc55NTpGXvJoDhGhwd
      ++zcHwCIPY8k09IgYJjAFWgJ8B7+plRDVq56OzyPOu3U+1HhAkEA3YRM/GjTfg7Y
      Y6O0uwhHe3M7wjOQkbrs7v8JZDu7RClZEe8het5qAumAZ8LG0UuXItG9eoJ5Ek1x
      7jY7SD8VNQJBANqezmKXmBjUANxjNV+tfFvlAUhJgTJRqEMzC8HwX2JWmgVKtae8
      LKwlLHxCcRgya+IH9FEW5KjfJochYvgS/g0CQEhEsm0iseUNaNFRBlSChfejh5p7
      Ai5ZIpVyRRkbV6QMLU/piS2xxDpA/bBcXkrH833bmYqPaHptI79ImByg4AUCQQDA
      ux/Xay17NetMX2m+X4MywEDRKXvskHB2TZof73kniJFf+O0MYqg/WsZNBYYOfuT8
      72ZD1prfBVtB5f0KFjRBAkEA1eP3qW8qaZi5/DUTOpxSUjE2ECtgw2E/BfLfJLQ9
      AD4I53WNUVeDyGaIVWIB5yHQfC2rZqGBwflGQG7o77+opQ==
      -----END RSA PRIVATE KEY-----
    EOF

    STARTUP_SCRIPT = <<-EOF.gsub(/^\s+/, '')
      #!/bin/sh
      mkdir -p /mnt/change/hobson_workspace
      cat >/mnt/change/hobson_workspace/config.yml <<CONFIG
      ---
      :redis:
        :host: master.hobson.changeeng.org
      :storage:
        :provider: AWS
        :aws_secret_access_key: 1pbSY9LtrIApAxICfzRGzASDAAPSGn7tsKH9/orh
        :aws_access_key_id: AKIAI6MGGNYJEPGAGD3Q
        :region: us-west-1
      CONFIG
      chown -R change:change /mnt/change
      sed -i 's/ruby-1.9.3-p0/ruby-1.9.3-p374/' /etc/init.d/hobson
      BUNDLE_GEMFILE=/home/change/hobson /home/change/.rvm/bin/rvm use ruby-1.9.3-p374 do bundle install
      monit start hobson
    EOF

  end
end
