# frozen_string_literal: true

require 'compliance_engine'

# A compliance engine data check
class ComplianceEngine::Check < ComplianceEngine::Component
  def settings
    element('settings')
  end

  def hiera
    return @hiera unless @hiera.nil?

    return @hiera = nil unless type == 'puppet-class-parameter'

    @hiera = { settings['parameter'] => settings['value'] }
  end

  def type
    element('type')
  end

  def remediation
    element('remediation')
  end

  def invalidate_cache(data = nil)
    @hiera = nil
    super
  end
end
