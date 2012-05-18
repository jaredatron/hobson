module Hobson

  def self.reset_encoding!
    Encoding.default_internal = (Hobson.config[:encoding].try(:[], :internal) || 'UTF-8' rescue 'UTF-8')
    Encoding.default_external = (Hobson.config[:encoding].try(:[], :external) || 'UTF-8' rescue 'UTF-8')
  end
end
Hobson.reset_encoding!
