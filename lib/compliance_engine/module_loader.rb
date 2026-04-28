# frozen_string_literal: true

require_relative '../compliance_engine'
require_relative 'data_loader/json'
require_relative 'data_loader/yaml'

# Load compliance engine data from a Puppet module
class ComplianceEngine::ModuleLoader
  # Initialize a ModuleLoader from a Puppet module path
  #
  # @param path [String] the path to the Puppet module
  # @param fileclass [File] the class to use for file operations (default: `File`)
  # @param dirclass [Dir] the class to use for directory operations (default: `Dir`)
  # @param zipfile_path [String, nil] the path to the zip file if loading from a zip archive
  # @param load_dotfiles [Boolean] whether to load files whose relative path contains
  #   a component (directory or filename) beginning with '.'. Defaults to false so that
  #   dotfiles are skipped during normal module scanning, matching the behavior of
  #   Ruby's Dir.glob on real filesystems. Set to true only when the caller explicitly
  #   needs dotfile support (e.g. zip-based environment loading).
  def initialize(path, fileclass: File, dirclass: Dir, zipfile_path: nil, load_dotfiles: false)
    raise ComplianceEngine::Error, "#{path} is not a directory" unless fileclass.directory?(path)

    @name = nil
    @version = nil
    @files = []
    @zipfile_path = zipfile_path

    # Read the Puppet module's metadata.json
    metadata_json = File.join(path.to_s, 'metadata.json')
    if fileclass.exist?(metadata_json)
      begin
        metadata = ComplianceEngine::DataLoader::Json.new(metadata_json, fileclass: fileclass)
        @name = metadata.data['name']
        @version = metadata.data['version']
      rescue StandardError => e
        ComplianceEngine.log.warn "Could not parse #{metadata_json}: #{e.message}"
      end
    end

    # In this directory, we want to look for all yaml and json files
    # under SIMP/compliance_profiles and simp/compliance_profiles.
    # The loops are structured this way (rather than building a flat globs
    # array first) so that each glob result can be checked against its
    # base directory for dotfile filtering.
    ['SIMP/compliance_profiles', 'simp/compliance_profiles'].each do |dir|
      base = File.join(path, dir)
      next unless fileclass.directory?(base)

      # Using .each here to make mocking with rspec easier.
      ['yaml', 'json'].each do |type|
        dirclass.glob(File.join(base, '**', "*.#{type}")).sort.each do |file|
          unless load_dotfiles
            # Skip any file whose path (relative to the compliance_profiles
            # base) contains a component beginning with '.', e.g. hidden
            # files (.profile.yaml) or files inside hidden directories
            # (.hidden/profile.yaml).
            relative = file.to_s.delete_prefix("#{base}/")
            next if relative.split('/').any? { |part| part.start_with?('.') }
          end

          key = if @zipfile_path
                  File.join(@zipfile_path, '.', file.to_s)
                else
                  file.to_s
                end
          loader = if File.extname(file.to_s) == '.json'
                     ComplianceEngine::DataLoader::Json.new(file.to_s, fileclass: fileclass, key: key)
                   else
                     ComplianceEngine::DataLoader::Yaml.new(file.to_s, fileclass: fileclass, key: key)
                   end
          @files << loader
        rescue StandardError => e
          ComplianceEngine.log.warn "Could not load #{file}: #{e.message}"
        end
      end
    end
  end

  attr_reader :name, :version, :files, :zipfile_path
end
