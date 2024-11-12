# frozen_string_literal: true

require 'compliance_engine'
require 'compliance_engine/data_loader/json'
require 'compliance_engine/data_loader/yaml'

# Load compliance engine data from a Puppet module
class ComplianceEngine::ModuleLoader
  # Initialize a ModuleLoader from a Puppet module path
  #
  # @param path [String] the path to the Puppet module
  # @param fileclass [File] the class to use for file operations (default: `File`)
  # @param dirclass [Dir] the class to use for directory operations (default: `Dir`)
  def initialize(path, fileclass: File, dirclass: Dir)
    raise ComplianceEngine::Error, "#{path} is not a directory" unless fileclass.directory?(path)

    @name = nil
    @version = nil
    @files = []

    # Read the Puppet module's metadata.json
    metadata_json = File.join(path.to_s, 'metadata.json')
    if fileclass.exist?(metadata_json)
      begin
        metadata = ComplianceEngine::DataLoader::Json.new(metadata_json, fileclass: fileclass)
        @name = metadata.data['name']
        @version = metadata.data['version']
      rescue => e
        warn "Could not parse #{metadata_json}: #{e.message}"
      end
    end

    # In this directory, we want to look for all yaml and json files
    # under SIMP/compliance_profiles and simp/compliance_profiles.
    globs = ['SIMP/compliance_profiles', 'simp/compliance_profiles']
            .select { |dir| fileclass.directory?(File.join(path, dir)) }
            .map { |dir|
      ['yaml', 'json'].map { |type| File.join(path, dir, '**', "*.#{type}") }
    }.flatten
    # debug "Globs: #{globs}"
    # Using .each here to make mocking with rspec easier.
    globs.each do |glob|
      dirclass.glob(glob).each do |file|
        key = if Object.const_defined?(:Zip) && file.is_a?(Zip::Entry)
                File.join(file.zipfile.to_s, '.', file.to_s)
              else
                file.to_s
              end
        loader = if File.extname(file.to_s) == '.json'
                   ComplianceEngine::DataLoader::Json.new(file.to_s, fileclass: fileclass, key: key)
                 else
                   ComplianceEngine::DataLoader::Yaml.new(file.to_s, fileclass: fileclass, key: key)
                 end
        @files << loader
      rescue => e
        warn "Could not load #{file}: #{e.message}"
      end
    end
  end

  attr_reader :name, :version, :files
end
