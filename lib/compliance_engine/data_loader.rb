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
  # The hash and all nested hashes and arrays within it are deep-frozen so
  # that parsed compliance data is treated as read-only once loaded.  String
  # values are replaced with frozen, deduplicated copies, so a String object
  # the caller still holds is not itself frozen and is no longer part of the
  # data.  A hash or array that is already frozen is replaced with a frozen
  # copy.  Callers must not retain a mutable reference to the hash after
  # calling this method.
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
  # @return [Object] the frozen object; a String or an already-frozen Hash or
  #   Array is returned as a different object, everything else is frozen
  #   in-place
  def deep_freeze(obj)
    case obj
    when Hash
      # A frozen container cannot have its values replaced with interned
      # strings, so it is replaced with a frozen copy instead.
      return obj.transform_values { |v| deep_freeze(v) }.freeze if obj.frozen?

      obj.transform_values! { |v| deep_freeze(v) }
    when Array
      return obj.map { |v| deep_freeze(v) }.freeze if obj.frozen?

      obj.map! { |v| deep_freeze(v) }
    when String
      return -obj
    end
    obj.freeze
  end
end
