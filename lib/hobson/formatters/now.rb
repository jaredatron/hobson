module Hobson
  module Formatters
    def self.now
      Time.respond_to?(:now_without_mock_time) ? Time.now_without_mock_time : Time.now
    end
  end
end
