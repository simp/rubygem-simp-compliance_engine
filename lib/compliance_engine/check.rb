# frozen_string_literal: true

require 'compliance_engine'

# A compliance engine data check
class ComplianceEngine::Check < ComplianceEngine::Component
  # Returns the settings of the check
  #
  # @return [Hash] the settings of the check
  def settings
    element['settings']
  end

  # Returns the Puppet class parameters of the check
  #
  # @return [Hash] the Puppet class parameters of the check
  def hiera
    return @hiera unless @hiera.nil?

    return @hiera = nil unless type == 'puppet-class-parameter'

    @hiera = { settings['parameter'] => settings['value'] }
  end

  # Returns the type of the check
  #
  # @return [String] the type of the check
  def type
    element['type']
  end

  # Returns the remediation data of the check
  #
  # @return [Hash] the remediation data of the check
  def remediation
    element['remediation']
  end
end
