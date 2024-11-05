# frozen_string_literal: true

require 'compliance_engine'
require 'compliance_engine/data_loader/file'

require 'json'

# Load compliance engine data from a JSON file
class ComplianceEngine::DataLoader::Json < ComplianceEngine::DataLoader::File
  def parse(content)
    JSON.parse(content)
  end
end
