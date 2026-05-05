# frozen_string_literal: true

require_relative '../../compliance_engine'
require_relative '../environment_loader'
# zip/filesystem must be required before any Zip::File instance is opened so
# that the per-instance dir/file accessors are wired up at open time.
require 'zip/filesystem'
require 'zip'

# Load compliance engine data from a raw zip byte string containing a Puppet environment
class ComplianceEngine::EnvironmentLoader::ZipBytes < ComplianceEngine::EnvironmentLoader
  # @param bytes [String] raw binary zip data (e.g. from File.binread or an HTTP body)
  # @param root [String] a directory within the zip file to use as the root of the environment
  # @param load_dotfiles [Boolean] whether to load dotfiles; defaults to true to
  #   preserve the historical zip-loader behaviour of including all files
  # @param name [String, nil] identifier used for modulepath and downstream
  #   cache keys; defaults to "-" when no filename is available.
  def initialize(bytes, root: '/'.dup, load_dotfiles: true, name: nil)
    raise ArgumentError, "bytes must be a String, got #{bytes.class}" unless bytes.is_a?(String)

    zipfile = ::Zip::File.open_buffer(bytes)
    @modulepath = name || '-'
    super(root, fileclass: zipfile.file, dirclass: zipfile.dir, zipfile_path: @modulepath, load_dotfiles: load_dotfiles)
  ensure
    zipfile&.close
  end
end
