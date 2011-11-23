require 'rspec/core/formatters/base_formatter'

RSpec.configure do |config|

  get_spec = proc{ |this|
    this.class.file_path.split(':').first #.split("#{::Rails.root}/").last
  }

  started_at = nil

  config.before :all do
    raise "started twice!" unless started_at.nil?
    spec = get_spec.call(self)
    puts "PROGRESS:STARTED:#{spec}"
    started_at = Time.now
  end

  config.after :all do
    spec = get_spec.call(self)

    status = begin
      self.class.descendant_filtered_examples \
        .map{ |t| t.metadata[:execution_result][:status] } \
        .any?{ |result| result == "failed" } ?
      'FAIL' : 'PASS'
    end

    duration = Time.now - started_at

    started_at = nil

    puts "PROGRESS:COMPLETED:#{spec}:#{status}:#{duration}"
  end

end

module Hobson::RSpec
  class Formatter < RSpec::Core::Formatters::BaseFormatter
    def initialize output
      super StringIO.new
    end
  end
end
