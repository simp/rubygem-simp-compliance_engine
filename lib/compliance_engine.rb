# frozen_string_literal: true

require 'compliance_engine/version'
require 'compliance_engine/data'

# Work with compliance data
module ComplianceEngine
  class Error < StandardError; end
  class ComplianceEngine < ComplianceEngine::Data; end

  def self.open(*paths)
    ComplianceEngine.new(*paths)
  end

  def self.new(*paths)
    ComplianceEngine.new(*paths)
  end
end
