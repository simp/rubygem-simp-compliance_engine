# frozen_string_literal: true

require_relative '../compliance_engine'
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
  # The hash and all nested hashes, arrays, and strings within it are
  # deep-frozen so that parsed compliance data is treated as read-only
  # once loaded.  Callers must not retain a mutable reference to the
  # hash after calling this method.
  #
  # @param value [Hash] The new value for the data loader
  # @raise [ComplianceEngine::Error] If the value is not a Hash
  def data=(value)
    raise ComplianceEngine::Error, 'Data must be a hash' unless value.is_a?(Hash)

    @data = deep_freeze(value)
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

  private

  # Recursively freezes a Hash or Array and all nested objects.
  #
  # Parsed compliance data is read-only once loaded; deep-freezing it makes
  # that invariant explicit and surfaces any accidental in-place mutation
  # immediately as a FrozenError rather than silent data corruption.
  #
  # String values are also interned (deduplicated).  Compliance data repeats
  # the same control, CE, and parameter names many times across files, and
  # the parsers allocate a new String for every occurrence that is not a
  # Hash key.  Interning them keeps a single copy of each distinct string.
  #
  # @param obj [Object] the object to freeze
  # @return [Object] the frozen object; a String may be returned as a
  #   different (interned) object, everything else is frozen in-place
  def deep_freeze(obj)
    case obj
    when Hash
      if obj.frozen?
        # A frozen container cannot have its values replaced, so its strings
        # are frozen where they are instead of being interned.
        obj.each_value { |v| v.is_a?(String) ? v.freeze : deep_freeze(v) }
      else
        obj.transform_values! { |v| deep_freeze(v) }
      end
    when Array
      if obj.frozen?
        obj.each { |v| v.is_a?(String) ? v.freeze : deep_freeze(v) }
      else
        obj.map! { |v| deep_freeze(v) }
      end
    when String
      return -obj
    end
    obj.freeze
  end
end
