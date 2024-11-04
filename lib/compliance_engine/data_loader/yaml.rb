# frozen_string_literal: true

require 'compliance_engine'
require 'compliance_engine/data_loader'

require 'yaml'

# Load compliance engine data from a YAML file
class ComplianceEngine::DataLoader::Yaml < ComplianceEngine::DataLoader
  def initialize(file)
    super(YAML.safe_load(File.read(file)), key: file)
  end

  def refresh
    self.data = YAML.safe_load(File.read(key))
  end

  attr_reader :key
end
