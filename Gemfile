# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in compliance_engine.gemspec
gemspec

gem 'rake', '~> 13.2.1'

group :tests do
  gem 'puppet', ENV.fetch('PUPPET_VERSION', '~> 8.0')
  gem 'rspec', '~> 3.12'
  gem 'rspec-puppet', '~> 5.0.0'
  gem 'rubocop', '~> 1.69.0'
  gem 'rubocop-performance', '~> 1.23.0'
  gem 'rubocop-rake', '~> 0.6.0'
  gem 'rubocop-rspec', '~> 3.3.0'
end

group :development do
  gem 'pry'
  gem 'pry-byebug'
  gem 'ruby-prof'
end
