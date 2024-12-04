# frozen_string_literal: true

require 'compliance_engine'
require 'compliance_engine/environment_loader'
require 'zip/filesystem'

# Load compliance engine data from a zip file containing a Puppet environment
class ComplianceEngine::EnvironmentLoader::Zip < ComplianceEngine::EnvironmentLoader
  # Initialize a ComplianceEngine::EnvironmentLoader::Zip object from a zip
  # file and an optional root directory.
  #
  # @param path [String] the path to the zip file containing the Puppet environment
  # @param root [String] a directory within the zip file to use as the root of the environment
  def initialize(path, root: '/'.dup)
    @modulepath = path

    ::Zip::File.open(path) do |zipfile|
      dir = zipfile.dir
      file = zipfile.file

      super(root, fileclass: file, dirclass: dir)
    end
  end
end
