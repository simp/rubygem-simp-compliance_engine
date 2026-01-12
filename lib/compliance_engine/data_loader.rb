# frozen_string_literal: true

require 'compliance_engine'
require 'observer'

# Load compliance engine data
class ComplianceEngine::DataLoader
  include Observable

  # Initialize a new instance of the ComplianceEngine::DataLoader::File class
  #
  # @param value [Hash] The data to initialize the object with
  # @param key [String] The key to use for identifying the data
  def initialize(value = {}, key: nil)
    self.data = value
    @key = key
  end

  attr_reader :data

  # Set the data for the data loader
  #
  # @param value [Hash] The new value for the data loader
  #
  # @raise [ComplianceEngine::Error] If the value is not a Hash
  def data=(value)
    raise ComplianceEngine::Error, 'Data must be a hash' unless value.is_a?(Hash)

    @data = value
    changed
    notify_observers(self)
  end

  # Get the key for the data loader
  #
  # The key is used to identify the data to observers. If a key is not
  # provided during initialization, a random UUID will be generated.
  #
  # @return [String] The key for the data loader
  def key
    return @key unless @key.nil?

    require 'securerandom'
    @key = "#{data.class}:#{SecureRandom.uuid}"
  end
end
