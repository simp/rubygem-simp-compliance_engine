# frozen_string_literal: true

require_relative '../../compliance_engine'
require_relative 'file'

require 'yaml'

# Load compliance engine data from a YAML file
class ComplianceEngine::DataLoader::Yaml < ComplianceEngine::DataLoader::File
  # Parse YAML content into a Hash
  #
  # @param [String] content The content to parse
  # @return [Hash]
  def parse(content)
    YAML.safe_load(content)
  end
end
