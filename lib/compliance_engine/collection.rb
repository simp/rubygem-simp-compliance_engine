# frozen_string_literal: true

require 'compliance_engine'

# A generic compliance engine data collection
class ComplianceEngine::Collection
  # A generic compliance engine data collection
  #
  # @param data [Object] the data to initialize the object with
  # @return [void]
  def initialize(data)
    @collection ||= {}
    hash_key = key
    data.files.each do |file|
      data.get(file)[hash_key]&.each do |k, v|
        @collection[k] ||= collected.new(k)
        @collection[k].add(v)
      end
    end
  end

  attr_accessor :collection

  # Converts the object to a hash representation.
  #
  # @return [Hash] the hash representation of the object.
  #
  # @fixme This should implement merge behavior.
  def to_h
    # FIXME: This should implement merge behavior.
    collection
  end

  # Returns the keys of the collection.
  #
  # @return [Array] the keys of the collection
  def keys
    # FIXME: Implement confinement
    collection.keys
  end

  private

  # Returns the key of the object.
  #
  # @return [NotImplementedError] This method is not implemented and should be overridden by subclasses.
  def key
    raise NotImplementedError
  end

  # Retrieves the collected data.
  #
  # Raises a NotImplementedError if the method is not implemented.
  #
  # @return [void]
  def collected
    raise NotImplementedError
  end
end
