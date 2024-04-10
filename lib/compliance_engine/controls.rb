# frozen_string_literal: true

require 'compliance_engine'

# A collection of compliance engine data controls
class ComplianceEngine::Controls < ComplianceEngine::Collection
  private

  # Returns the key of the collection in compliance engine source data
  #
  # @return [String]
  def key
    'controls'
  end

  # Returns the class to use for the collection
  #
  # @return [Class]
  def collected
    ComplianceEngine::Control
  end
end
