# frozen_string_literal: true

require_relative '../../compliance_engine'
require_relative '../environment_loader'
require 'zip/filesystem'

# Load compliance engine data from a zip file containing a Puppet environment
class ComplianceEngine::EnvironmentLoader::Zip < ComplianceEngine::EnvironmentLoader
  # Initialize a ComplianceEngine::EnvironmentLoader::Zip object from a zip
  # file and an optional root directory.
  #
  # @param input [String, ::Zip::File] either a filesystem path to a zip file,
  #   or an already-opened ::Zip::File (e.g. from Zip::File.open_buffer); when
  #   a ::Zip::File is passed, the caller owns its lifecycle
  # @param root [String] a directory within the zip file to use as the root of the environment
  # @param load_dotfiles [Boolean] whether to load dotfiles; defaults to true to
  #   preserve the historical zip-loader behaviour of including all files
  # @param name [String, nil] identifier used for modulepath and downstream
  #   cache keys; defaults to the zip's #name (the path on disk, or "-" for
  #   buffer-opened zips). Pass an explicit value when loading a buffer-opened
  #   zip to keep cache keys unique and logs informative.
  def initialize(input, root: '/'.dup, load_dotfiles: true, name: nil)
    zipfile = input.is_a?(::Zip::File) ? input : ::Zip::File.open(input)
    @modulepath = name || zipfile.name
    super(root, fileclass: zipfile.file, dirclass: zipfile.dir, zipfile_path: @modulepath, load_dotfiles: load_dotfiles)
  ensure
    zipfile.close if zipfile && !input.is_a?(::Zip::File)
  end
end
