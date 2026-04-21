# frozen_string_literal: true

require_relative '../../compliance_engine'
require_relative '../environment_loader'
require 'zip/filesystem'

# Load compliance engine data from a zip file containing a Puppet environment
class ComplianceEngine::EnvironmentLoader::Zip < ComplianceEngine::EnvironmentLoader
  # Initialize a ComplianceEngine::EnvironmentLoader::Zip object from a zip
  # file and an optional root directory.
  #
  # @param path [String] the path to the zip file containing the Puppet environment
  # @param root [String] a directory within the zip file to use as the root of the environment
  # @param load_dotfiles [Boolean] whether to load dotfiles; defaults to true to
  #   preserve the historical zip-loader behaviour of including all files
  def initialize(path, root: '/'.dup, load_dotfiles: true)
    @modulepath = path

    ::Zip::File.open(path) do |zipfile|
      dir = zipfile.dir
      file = zipfile.file

      super(root, fileclass: file, dirclass: dir, zipfile_path: path, load_dotfiles: load_dotfiles)
    end
  end
end
