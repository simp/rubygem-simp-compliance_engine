# frozen_string_literal: true

require 'compliance_engine'
require 'thor'

# Compliance Engine CLI
class ComplianceEngine::CLI < Thor
  class_option :facts, type: :string
  class_option :enforcement_tolerance, type: :numeric
  class_option :module, type: :array, default: []

  desc 'hiera', 'Dump Hiera data'
  option :profile, type: :array, required: true
  def hiera
    data = ComplianceEngine::Data.new(*options[:module], facts: facts, enforcement_tolerance: options[:enforcement_tolerance])
    require 'yaml'
    puts data.hiera(options[:profile]).to_yaml
  end

  desc 'lookup KEY', 'Look up a Hiera key'
  option :profile, type: :array, required: true
  def lookup(key)
    data = ComplianceEngine::Data.new(*options[:module], facts: facts, enforcement_tolerance: options[:enforcement_tolerance])
    require 'yaml'
    puts data.hiera(options[:profile]).select { |k, _| k == key }.to_yaml
  end

  desc 'dump', 'Dump all compliance data'
  def dump
    data = ComplianceEngine::Data.new(*options[:module], facts: facts, enforcement_tolerance: options[:enforcement_tolerance])
    require 'yaml'
    data.files.each do |file|
      puts({ file => data.get(file) }.to_yaml)
    end
  end

  desc 'profiles', 'List available profiles'
  def profiles
    data = ComplianceEngine::Data.new(*options[:module], facts: facts, enforcement_tolerance: options[:enforcement_tolerance])
    require 'yaml'
    puts data.profiles.select { |_, value| value.ces&.count&.positive? || value.controls&.count&.positive? }.keys.to_yaml
  end

  desc 'inspect', 'Start an interactive shell'
  def inspect
    # Run the CLI with `data` as the object containing the compliance data.
    data = ComplianceEngine::Data.new(*options[:module], facts: facts, enforcement_tolerance: options[:enforcement_tolerance])

    require 'irb'
    # rubocop:disable Lint/Debugger
    binding.irb
    # rubocop:enable Lint/Debugger
  end

  private

  def facts
    return nil unless options[:facts]
    return @facts unless @facts.nil?

    require 'json'

    @facts = JSON.parse(options[:facts])
  end
end
