# frozen_string_literal: true

require 'compliance_engine'

# A collection of compliance engine data CEs
class ComplianceEngine::Ces < ComplianceEngine::Collection
  private

  def key
    'ce'
  end

  def collected
    ComplianceEngine::Ce
  end
end
