# frozen_string_literal: true

require 'compliance_engine'
require 'compliance_engine/data_loader'

require 'json'

# Load compliance engine data from a JSON file
class ComplianceEngine::DataLoader::Json < ComplianceEngine::DataLoader
  def initialize(file)
    super(JSON.parse(File.read(file)), key: file)
  end

  def refresh
    self.data = JSON.parse(File.read(key))
  end

  attr_reader :key
end
