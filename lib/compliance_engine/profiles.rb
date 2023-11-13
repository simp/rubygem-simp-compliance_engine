# frozen_string_literal: true

require 'compliance_engine'

# A collection of compliance engine data profiles
class ComplianceEngine::Profiles < ComplianceEngine::Collection
  private

  def key
    'profiles'
  end

  def collected
    ComplianceEngine::Profile
  end
end
