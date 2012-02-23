source "http://rubygems.org"

gemspec

gem 'redis-slave', :git => "git://github.com/deadlyicon/redis-slave.git"


group :development, :test do

  platform :ruby_18 do
    gem "ruby-debug"
  end

  platform :ruby_19 do
    gem 'linecache19', :git => 'git://github.com/mark-moseley/linecache'
    gem 'ruby-debug-base19x', '~> 0.11.30.pre4'
    gem "ruby-debug19"
  end

  gem 'rake'
  gem 'shotgun'
  gem 'rspec'
  gem 'resque_unit'

end
