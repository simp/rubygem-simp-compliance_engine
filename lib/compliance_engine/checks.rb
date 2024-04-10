# frozen_string_literal: true

require 'compliance_engine'

# A collection of compliance engine data checks
class ComplianceEngine::Checks < ComplianceEngine::Collection
  private

  # Returns the key of the collection in compliance engine source data
  #
  # @return [String]
  def key
    'checks'
  end

  # Returns the class to use for the collection
  #
  # @return [Class]
  def collected
    ComplianceEngine::Check
  end
end
