# frozen_string_literal: true

require 'compliance_engine'
require 'compliance_engine/data_loader/file'

require 'json'

# Load compliance engine data from a JSON file
class ComplianceEngine::DataLoader::Json < ComplianceEngine::DataLoader::File
  # Parse JSON content into a Hash
  #
  # @param [String] content The content to parse
  # @return [Hash]
  def parse(content)
    JSON.parse(content)
  end
end
