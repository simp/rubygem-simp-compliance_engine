# frozen_string_literal: true

require 'compliance_engine'

# A collection of compliance engine data checks
class ComplianceEngine::Checks < ComplianceEngine::Collection
  private

  def key
    'checks'
  end

  def collected
    ComplianceEngine::Check
  end
end
