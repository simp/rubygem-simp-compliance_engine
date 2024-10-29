# frozen_string_literal: true

require 'compliance_engine'

# A compliance engine data profile
class ComplianceEngine::Profile < ComplianceEngine::Component
  # Returns the checks of the profile
  #
  # @return [Hash] the checks of the profile
  def checks
    element['checks']
  end
end
