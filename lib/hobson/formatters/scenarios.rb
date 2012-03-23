# prints each scenario name as a regexp so we can run scenarios by name
#
# cucumber --dry-run --no-profile -f
#
require 'cucumber'
require 'cucumber/formatter/io'

module Hobson
  module Formatters
    class Scenarios

      include ::Cucumber::Formatter::Io

      def initialize step_mother, path_or_io, options
        @io = ensure_io(path_or_io, "hobson_status")
      end

      def scenario_name keyword, name, file_colon_line, source_indent
        @io.puts name
      end

    end
  end
end
