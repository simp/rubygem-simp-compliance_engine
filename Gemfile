# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in compliance_engine.gemspec
gemspec

gem 'rake', '~> 13.3.0'

group :tests do
  gem 'openvox', ENV.fetch('OPENVOX_VERSION', ENV.fetch('PUPPET_VERSION', '~> 8.0'))
  gem 'syslog', require: false
  gem 'voxpupuli-test', '~> 13.0'
end

group :development do
  gem 'pry'
  gem 'pry-byebug'
  gem 'ruby-prof'
end
