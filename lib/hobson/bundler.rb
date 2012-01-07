require 'bundler'

module Hobson::Bundler

  def self.with_clean_env
    ::Bundler.with_clean_env{

      # this fixes a bug in older version of bundler
      ENV.delete("BUNDLE_BIN_PATH")
      ENV.delete("BUNDLE_GEMFILE")
      ENV["RUBYOPT"] = ENV["RUBYOPT"].gsub('-rbundler/setup', ' ') if ENV["RUBYOPT"]

      return yield
    }
  end

end
