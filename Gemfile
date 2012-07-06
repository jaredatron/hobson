source "http://rubygems.org"

gemspec

group :development do

  platform :ruby_18 do
    gem "ruby-debug"
  end

  platform :ruby_19 do
    gem 'debugger'
  end

  gem 'shotgun'

  gem 'capistrano'
  gem 'rvm-capistrano'
end

group :development, :test do
  gem 'rake'
  gem 'rspec'
  gem 'resque_unit'
  gem 'thin'
end

gem 'unicorn'
