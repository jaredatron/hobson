require 'tempfile'
require 'log4r'

module Hobson

  def log
    @log or begin
      @log = Pathname.new(ENV['HOBSON_LOG'] || config[:log] || root.join('log/hobson.log'))
      ENV['HOBSON_LOG'] ||= @log.to_s
    end
    @log
  end

  def log_outputter
    @log_outputter ||= begin
      log.dirname.mkpath
      file_outputter('hobson.log', log.to_s)
    end
  end

  def logger
    @logger ||= Log4r::Logger.new('Hobson').tap{|logger| logger.outputters = [log_outputter] }
  end

  def log_to_stdout!
    return if logging_to_stdout?
    @logging_to_stdout = true
    logger.outputters << Log4r::StdoutOutputter.new('Hobson', :formatter => LogFormatter.new)
  end

  def logging_to_stdout?
    @logging_to_stdout
  end

  attr_reader :temp_logfile

  def log_to_a_tempfile &block
    @temp_logfile = Tempfile.new('Hobson.temp_log')
    temp_log_outputter = file_outputter('hobson.log', @temp_logfile.path)
    logger.outputters << temp_log_outputter
    yield
  ensure
    logger.outputters = logger.outputters - [temp_log_outputter]
    @temp_logfile.close
    @temp_logfile.unlink
    @temp_logfile = nil
  end

  def logging_to_a_tempfile?
    @temp_log.present?
  end

  private

  def start_logging_to_a_tempfile_file!
    return if logging_to_a_file?
    @logging_to_a_file = true
    Hobson::LOGGER.outputters << Log4r::FileOutputter.new('tempfile',
      :filename  => log_path,
      :formatter => LogFormatter.new
    )
  end

  def file_outputter name, filename
    Log4r::FileOutputter.new(name, :filename => filename, :formatter => LogFormatter.new)
  end

  class LogFormatter < Log4r::Formatter
    def format event
      if Log4r::LNAMES[event.level] == 'DEBUG'
        event.data.to_s+"\n"
      else
        prefix = "#{event.fullname}: "
        event.data.to_s.split(/\n/).map{|line| "#{prefix}#{line}" }.join("\n")+"\n"
      end
    end
  end

end
