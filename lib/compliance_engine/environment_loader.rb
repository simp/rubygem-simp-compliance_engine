# frozen_string_literal: true

require_relative '../compliance_engine'
require_relative 'module_loader'

# Load compliance engine data from a Puppet environment
class ComplianceEngine::EnvironmentLoader
  # Initialize an EnvironmentLoader from the components of a Puppet `modulepath`
  #
  # @param paths [Array] the paths to search for Puppet modules
  # @param fileclass [File] the class to use for file operations (default: `File`)
  # @param dirclass [Dir] the class to use for directory operations (default: `Dir`)
  # @param zipfile_path [String, nil] the path to the zip file if loading from a zip archive
  # @param load_dotfiles [Boolean] whether to load dotfiles; passed through to
  #   each ModuleLoader (default: false)
  def initialize(*paths, fileclass: File, dirclass: Dir, zipfile_path: nil, load_dotfiles: false)
    raise ArgumentError, 'No paths specified' if paths.empty?

    @modulepath ||= paths
    @zipfile_path = zipfile_path
    modules = paths.map do |path|
      dirclass.entries(path)
              .grep(%r{\A[a-z][a-z0-9_]*\Z})
              .select { |child| fileclass.directory?(File.join(path, child)) }
              .map { |child| File.join(path, child) }
              .sort
    rescue StandardError
      []
    end
    modules.flatten!
    @modules = modules.map { |path| ComplianceEngine::ModuleLoader.new(path, fileclass: fileclass, dirclass: dirclass, zipfile_path: @zipfile_path, load_dotfiles: load_dotfiles) }
  end

  attr_reader :modulepath, :modules, :zipfile_path
end
