# frozen_string_literal: true

require 'compliance_engine/version'
require 'compliance_engine/data'

# Work with compliance data
module ComplianceEngine
  class Error < StandardError; end

  # Open compliance data
  #
  # @param [Array<String>] paths The paths to the compliance data files
  # @return [ComplianceEngine::Data]
  def self.open(*paths)
    Data.new(*paths)
  end

  # Open compliance data
  #
  # @param [Array<String>] paths The paths to the compliance data files
  # @return [ComplianceEngine::Data]
  def self.new(*paths)
    Data.new(*paths)
  end
end
