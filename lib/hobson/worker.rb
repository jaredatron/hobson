class Hobson::Worker < Resque::Worker

  attr_accessor :options

  def initialize options = {}
    super('*')
    @options = options
    options[:pidfile] ||= ENV['PIDFILE']
    @verbose = true
    @very_verbose = $DEBUG
    if options[:daemonize]
      pid = ::Process.fork{ work }
      Process.detach(pid)
      puts "Daemonized a resque worker with pid #{pid}"
    else
      puts "Becoming a resque worker"
      work
    end
  end

  def work
    File.open(options[:pidfile], 'w') { |f| f << $$ } if options[:pidfile]
    super{ |job| Hobson.logger.info "job complete #{job}" }
  end

  def procline(string)
    $0 = "Hobson #{hostname}:#{Process.pid} - #{string}"
    log! $0
  end

end
