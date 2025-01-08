# frozen_string_literal: true

require 'compliance_engine'
require 'thor'

# Compliance Engine CLI
class ComplianceEngine::CLI < Thor
  class_option :facts, type: :string
  class_option :enforcement_tolerance, type: :numeric
  class_option :module, type: :array, default: []
  class_option :modulepath, type: :array
  class_option :modulezip, type: :string
  class_option :verbose, type: :boolean
  class_option :debug, type: :boolean

  desc 'version', 'Print the version'
  def version
    puts ComplianceEngine::VERSION
  end

  desc 'hiera', 'Dump Hiera data'
  option :profile, type: :array, required: true
  def hiera
    require 'yaml'
    puts data.hiera(options[:profile]).to_yaml
  end

  desc 'lookup KEY', 'Look up a Hiera key'
  option :profile, type: :array, required: true
  def lookup(key)
    require 'yaml'
    puts data.hiera(options[:profile]).select { |k, _| k == key }.to_yaml
  end

  desc 'dump', 'Dump all compliance data'
  def dump
    require 'yaml'
    data.files.each do |file|
      puts({ file => data.get(file) }.to_yaml)
    end
  end

  desc 'profiles', 'List available profiles'
  def profiles
    require 'yaml'
    puts data.profiles.select { |_, value| value.ces&.count&.positive? || value.controls&.count&.positive? }.keys.to_yaml
  end

  desc 'inspect', 'Start an interactive shell'
  def inspect
    # Run the CLI with `data` as the object containing the compliance data.
    require 'irb'
    # rubocop:disable Lint/Debugger
    binding.irb
    # rubocop:enable Lint/Debugger
  end

  private

  def data
    return @data unless @data.nil?

    if options[:debug]
      ComplianceEngine.log.level = Logger::DEBUG
    elsif options[:verbose]
      ComplianceEngine.log.level = Logger::INFO
    end
    @data = ComplianceEngine::Data.new
    @data.facts = facts
    @data.enforcement_tolerance = options[:enforcement_tolerance]
    if options[:modulezip]
      @data.open_environment_zip(options[:modulezip])
    elsif options[:modulepath]
      @data.open_environment(*options[:modulepath])
    else
      @data.open(*options[:module])
    end

    @data
  end

  def facts
    return nil unless options[:facts]
    return @facts unless @facts.nil?

    require 'json'

    @facts = JSON.parse(options[:facts])
  end
end
