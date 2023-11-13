# frozen_string_literal: true

require 'compliance_engine'

# A collection of compliance engine data controls
class ComplianceEngine::Controls < ComplianceEngine::Collection
  private

  def key
    'controls'
  end

  def collected
    ComplianceEngine::Control
  end
end
