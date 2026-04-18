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

# Acceptance tests (requires `bundle install --with acceptance`)
# voxpupuli-acceptance wraps beaker/beaker-docker; BEAKER_SETFILE selects the
# nodeset (a beaker-hostgenerator spec string or a path to a custom YAML file).
#
# If multi-node support turns out to need features beyond what
# voxpupuli-acceptance exposes, replace this with direct beaker/beaker-docker
# rake tasks.
begin
  require 'rspec/core/rake_task'
  require 'voxpupuli/acceptance/rake'

  namespace :acceptance do
    desc 'Run puppet apply acceptance tests (single openvox-agent node, set BEAKER_SETFILE=alma9-64)'
    RSpec::Core::RakeTask.new(:apply) do |t|
      t.pattern = 'spec/acceptance/01_apply_spec.rb'
    end

    desc 'Run puppet server/agent acceptance tests (set BEAKER_SETFILE=spec/acceptance/nodesets/server_agent.yml)'
    RSpec::Core::RakeTask.new(:server) do |t|
      t.pattern = 'spec/acceptance/0{2,3,4}_*_spec.rb'
    end
  end
rescue LoadError
  # voxpupuli-acceptance not installed; run `bundle install --with acceptance`
end
