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

# Puppet module build (requires `bundle install` with the release group).
#
# puppet-modulebuilder 2.x dropped support for .pdkignore; this subclass
# restores it so the published module package matches what PDK produced.
begin
  require 'puppet/modulebuilder'

  class PdkCompatBuilder < Puppet::Modulebuilder::Builder
    def ignored_files
      spec = super
      pdkignore = File.join(source, '.pdkignore')
      return spec unless File.exist?(pdkignore)

      File.readlines(pdkignore, chomp: true).each do |line|
        next if line.strip.empty? || line.start_with?('#')

        spec.add(line)
      end
      spec
    end
  end

  namespace :module do
    desc 'Build the Puppet module package into pkg/, honouring .pdkignore'
    task :build do
      builder = PdkCompatBuilder.new(Dir.pwd)
      pkg = builder.build
      puts "Built: #{pkg}"
    end
  end
rescue LoadError
  # puppet-modulebuilder not installed; run `bundle install` with the release group
end
