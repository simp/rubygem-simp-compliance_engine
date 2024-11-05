# frozen_string_literal: true

require 'compliance_engine'
require 'compliance_engine/data_loader/file'

require 'yaml'

# Load compliance engine data from a YAML file
class ComplianceEngine::DataLoader::Yaml < ComplianceEngine::DataLoader::File
  def parse(content)
    YAML.safe_load(content)
  end
end
