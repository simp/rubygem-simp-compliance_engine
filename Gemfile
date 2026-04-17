# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in compliance_engine.gemspec
gemspec

gem 'rake', '~> 13.4.0'

group :tests do
  # renovate: datasource=rubygems versioning=ruby
  gem 'openvox', ENV.fetch('OPENVOX_VERSION', ENV.fetch('PUPPET_VERSION', '~> 8.0'))
  gem 'syslog', require: false, platforms: :mri
  gem 'voxpupuli-test', '~> 14.0'
end

group :release do
  gem 'puppet-modulebuilder', '~> 2.0', require: false
end

group :development do
  gem 'pry'
  gem 'pry-byebug', platforms: :mri
  gem 'ruby-prof', platforms: :mri
end
