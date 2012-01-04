require 'rspec'
require 'rspec/core/formatters/base_formatter'

RSpec.configure do |config|

  get_spec = proc{ |this|
    this.class.file_path.split(':').first.split("#{::RSpec::Core::RubyProject.root}/").last
  }

  started_at = nil

  config.before :all do
    spec = get_spec.call(self)
    puts "TEST:#{spec}:START:#{Time.now.to_i}"
  end

  config.after :all do
    spec = get_spec.call(self)

    status = begin
      self.class.descendant_filtered_examples \
        .map{ |t| t.metadata[:execution_result][:status] } \
        .any?{ |result| result == "failed" } ?
      'FAIL' : 'PASS'
    end

    puts "TEST:#{spec}:COMPLETE:#{Time.now.to_i}:#{status}"
  end

end

module Hobson
  module RSpec
    class Formatter < ::RSpec::Core::Formatters::BaseFormatter
      def initialize output
        super StringIO.new
      end
    end
  end
end
