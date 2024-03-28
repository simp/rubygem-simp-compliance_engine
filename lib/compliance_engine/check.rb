# frozen_string_literal: true

require 'compliance_engine'

# A compliance engine data check
class ComplianceEngine::Check < ComplianceEngine::Component
  def settings
    element(:settings, 'settings')
  end

  def type
    element(:type, 'type')
  end

  def remediation
    element(:remediation, 'remediation')
  end
end
