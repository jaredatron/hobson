class Hobson::Worker < Resque::Worker

  class << self

    # become a resque-worker and handle hobson resque jobs
    def become! options={}
      if options[:daemonize]
        pid = fork{ work! options }
        puts "Daemonized a worker with pid #{pid}"
        Process.detach(pid)
      else
        puts "Becoming a worker"
        work! options
      end
    end

    private

    def work! options={}
      Hobson.resque # ensure resque is all setup
      options[:pidfile] ||= ENV['PIDFILE']
      worker = new
      worker.verbose = true
      worker.very_verbose = $DEBUG
      Hobson.logger.info "started worker #{worker}"
      puts "started worker #{worker}"
      p Hobson.resque.redis.smembers("workers");
      File.open(options[:pidfile], 'w') { |f| f << worker.pid } if options[:pidfile]
      worker.work
    end

  end

  def initialize
    @parent_pid = $$
    super '*'
  end

  def parent?
    $$ == @parent_pid
  end

  def child?
    !parent?
  end

  def proc_name
    parent? ? "Hobson Worker (#{Hobson.git_version[0..8]})" : "Hobson Test Runner for #{@parent_pid}"
  end

  def procline(string)
    $0 = "#{proc_name}: #{string}"
    log! $0
  end

  # an "improved" prune_dead_workers
  # resque looks for processes by name by grepping `ps` and if it doesnt find
  # workers registered to this hostname it removed them from it's list of workers
  # this is buggy so before we use the pids and jsut confirm that that pid is
  # running and assume its the worker process we have registerede confirm
  def prune_dead_workers
    pids = `ps -A -o pid`.split("\n")[1..-1].map(&:to_i)
    Resque::Worker.all{|worker|
      host, pid, queues = worker.id.split(':')
      next host != hostname || pids.include?(pid)
      log! "Pruning dead worker: #{worker}"
      worker.unregister_worker
    }
  end

end
