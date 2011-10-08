require 'tempfile'
require 'log4r'

module Hobson

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

  LOGGER = Log4r::Logger.new('Hobson')

  Hobson::LOGGER.outputters = []

  def logger; LOGGER; end

  def start_logging_to_stdout!
    return if logging_to_stdout?
    @logging_to_stdout = true
    Hobson::LOGGER.outputters << Log4r::StdoutOutputter.new('Hobson', :formatter => LogFormatter.new)
  end

  def logging_to_stdout?
    @logging_to_stdout
  end

  def logfile_path
    Pathname.new(File.expand_path('~')).join('hobson.log').to_s
  end

  def start_logging_to_a_file!
    return if logging_to_a_file?
    @logging_to_a_file = true
    Hobson::LOGGER.outputters << Log4r::FileOutputter.new('tempfile',
      :filename  => logfile_path,
      :formatter => LogFormatter.new
    )
  end

  def logging_to_a_file?
    @logging_to_a_file
  end

end
