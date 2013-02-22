require 'hobson'
require 'fog'

module Hobson
  module Servers
    extend self

    def startup!(n)
      n -= Hobson.resque.workers.count
      n.times do
        fog.servers.create(
          image_id: 'ami-fc74e795',
          flavor_id: 'm1.large',
          key_name: 'change',
          groups: ['change_ci'],
          tags: {"Name" => "Hobson Worker"},
          user_data: STARTUP_SCRIPT,
        )
      end
    end

    def shutdown!(n)
      puts "Sending quit to workers..."
      servers_and_workers.each do |server, worker|
        pid = worker.id.split(':')[1]
        server.ssh("sudo monit unmonitor hobson && kill -s QUIT #{pid}")
      end

      print "Waiting for workers to finish..."
      until Hobson.resque.workers.count == 0
        sleep 5
        print '.'
      end
      puts

      puts "Terminating instances..."
      hobson_servers.each(&:destroy)

      startup!(n)
    end

    def audit_workers!
      servers_and_workers.each do |server, worker|
        pid = worker.id.split(':')[1]
        unless server.ssh("kill -0 #{pid}").first.status == 0
          print "Cleaning stale worker #{worker.id}..."
          cleanup_old_worker! worker.id
          puts 'done!'
        end
      end
    end

    def pause!
      servers_and_workers.each do |server, worker|
        pid = worker.id.split(':')[1]
        server.ssh("kill -s USR2 #{pid}")
      end
    end

    def quit!
      servers_and_workers.each do |server, worker|
        pid = worker.id.split(':')[1]
        server.ssh("kill -s QUIT #{pid}")
      end
    end

    def continue!
      servers_and_workers.each do |server, worker|
        pid = worker.id.split(':')[1]
        server.ssh("kill -s CONT #{pid}")
      end
    end

    def hobson_servers
      @hobson_servers ||= fog.servers.select { |s|
          s.state == 'running' && s.tags["Name"] == "Hobson Worker"
        }.each { |s|
          s.username = 'change'
          s.private_key = PRIVATE_KEY
        }
    end

    def servers_and_workers
      @servers_and_workers ||= Hobson.resque.workers.inject([]) do |result, worker|
        hostname = worker.id.split(':').first
        result << [hobson_servers.select { |s| s.private_dns_name =~ /#{hostname}/ }.first, worker]
      end
    end

    private

    def fog
      @fog ||= Fog::Compute.new(
          provider: 'AWS',
          aws_access_key_id: 'AKIAI6MGGNYJEPGAGD3Q',
          aws_secret_access_key: '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',
        )
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
      mkdir /mnt/change
      mv /home/change/hobson_workspace /mnt/change/hobson_workspace
      chown -R change:change /mnt/change
      ln -sf /mnt/change/hobson_workspace /home/change/hobson_workspace
      chown -R change:change /home/change/hobson_workspace
      monit start hobson
    EOF

  end
end
