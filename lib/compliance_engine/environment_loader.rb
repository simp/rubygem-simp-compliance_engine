# frozen_string_literal: true

require 'compliance_engine'
require 'compliance_engine/module_loader'

# Load compliance engine data from a Puppet environment
class ComplianceEngine::EnvironmentLoader
  # Initialize an EnvironmentLoader from the components of a Puppet `modulepath`
  #
  # @param paths [Array] the paths to search for Puppet modules
  # @param fileclass [File] the class to use for file operations (default: `File`)
  # @param dirclass [Dir] the class to use for directory operations (default: `Dir`)
  def initialize(*paths, fileclass: File, dirclass: Dir)
    raise ArgumentError, 'No paths specified' if paths.empty?
    @modulepath ||= paths
    modules = paths.map do |path|
      dirclass.entries(path)
              .grep(%r{\A[a-z][a-z0-9_]*\Z})
              .select { |child| fileclass.directory?(File.join(path, child)) }
              .map { |child| File.join(path, child) }
              .sort
    rescue
      []
    end
    modules.flatten!
    @modules = modules.map { |path| ComplianceEngine::ModuleLoader.new(path, fileclass: fileclass, dirclass: dirclass) }
  end

  attr_reader :modulepath, :modules
end
