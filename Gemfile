# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in compliance_engine.gemspec
gemspec

gem 'rake', '~> 13.4.0'

# rdoc 8 depends on rbs, which only ships a C extension (no java platform gem),
# so `bundle install` fails on JRuby. rdoc comes in transitively by way of
# voxpupuli-test -> openvox-strings -> irb -> rdoc, so pin it here until rbs
# publishes JRuby-compatible releases.
gem 'rdoc', '< 8', platforms: :jruby, require: false

group :tests do
  # json 3 breaks openvox (Puppet::Util::Json.load passes an options Hash
  # positionally) and jgrep, via facterdb (JSON.create_id=). voxpupuli-test 14 capped json
  # below 3 implicitly via rubocop 1.85; voxpupuli-test 15 does not.
  gem 'json', '>= 2.3', '< 4'
  # renovate: datasource=rubygems versioning=ruby
  gem 'openvox', ENV.fetch('OPENVOX_VERSION', ENV.fetch('PUPPET_VERSION', '~> 9.0'))
  gem 'syslog', require: false
  gem 'voxpupuli-test', '~> 15.0'
end

group :release do
  gem 'puppet-modulebuilder', '~> 2.0', require: false
end

group :acceptance do
  gem 'voxpupuli-acceptance', '~> 4.0', platforms: :mri
end

group :development do
  gem 'pry'
  gem 'pry-byebug', platforms: :mri
  gem 'ruby-prof', platforms: :mri
end
