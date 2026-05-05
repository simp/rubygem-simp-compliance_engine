# frozen_string_literal: true

require_relative '../../compliance_engine'
require_relative '../environment_loader'
require 'zip/filesystem'

# Load compliance engine data from a zip file containing a Puppet environment
class ComplianceEngine::EnvironmentLoader::Zip < ComplianceEngine::EnvironmentLoader
  # Initialize a ComplianceEngine::EnvironmentLoader::Zip object from a zip
  # file path and an optional root directory.
  #
  # @param input [String] filesystem path to a zip file
  # @param root [String] a directory within the zip file to use as the root of the environment
  # @param load_dotfiles [Boolean] whether to load dotfiles; defaults to true to
  #   preserve the historical zip-loader behaviour of including all files
  # @param name [String, nil] identifier used for modulepath and downstream
  #   cache keys; defaults to the full path string passed as +input+.
  def initialize(input, root: '/'.dup, load_dotfiles: true, name: nil)
    raise ArgumentError, "input must be a String path, got #{input.class}" unless input.is_a?(String)

    zipfile = ::Zip::File.open(input)
    @modulepath = name || input.to_s
    super(root, fileclass: zipfile.file, dirclass: zipfile.dir, zipfile_path: @modulepath, load_dotfiles: load_dotfiles)
  ensure
    zipfile&.close
  end
end
