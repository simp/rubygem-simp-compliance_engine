# frozen_string_literal: true

require 'compliance_engine/version'
require 'compliance_engine/data'

# Work with compliance data
module ComplianceEngine
  class Error < StandardError; end

  def self.open(*paths)
    Data.new(*paths)
  end

  def self.new(*paths)
    Data.new(*paths)
  end
end
