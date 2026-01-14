# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'voxpupuli/test/rake'

# Override the default spec task from voxpupuli-test to exclude spec/data and spec/fixtures
Rake::Task[:spec].clear
Rake::Task['spec:standalone'].clear

RSpec::Core::RakeTask.new('spec:standalone') do |t|
  t.pattern = 'spec/{classes,functions}/**/*_spec.rb'
end

desc 'Prepare fixtures for testing'
task spec_prep: :'fixtures:prep'

desc 'Clean up fixtures after testing'
task spec_clean: :'fixtures:clean'

desc 'Run spec tests and clean the fixtures directory if successful'
task spec: :'fixtures:prep' do |_t, args|
  Rake::Task['spec:standalone'].invoke(*args.extras)
  Rake::Task['fixtures:clean'].invoke
end

task default: [:spec, :rubocop]
