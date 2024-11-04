# frozen_string_literal: true

require 'compliance_engine'
require 'observer'

# Load compliance engine data
class ComplianceEngine::DataLoader
  include Observable

  def initialize(value = {}, key: nil)
    self.data = value
    @key = key
  end

  attr_reader :data

  def data=(value)
    raise ComplianceEngine::Error, 'Data must be a hash' unless value.is_a?(Hash)
    @data = value
    changed
    notify_observers(self)
  end

  def key
    return @key unless @key.nil?

    require 'securerandom'
    @key = SecureRandom.uuid
  end
end
