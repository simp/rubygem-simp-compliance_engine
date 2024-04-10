# frozen_string_literal: true

require 'compliance_engine'

# A collection of compliance engine data profiles
class ComplianceEngine::Profiles < ComplianceEngine::Collection
  private

  # Returns the key of the collection in compliance engine source data
  #
  # @return [String]
  def key
    'profiles'
  end

  # Returns the class to use for the collection
  #
  # @return [Class]
  def collected
    ComplianceEngine::Profile
  end
end
