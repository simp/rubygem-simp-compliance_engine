# frozen_string_literal: true

require 'compliance_engine'

# A generic compliance engine data collection
class ComplianceEngine::Collection
  # A generic compliance engine data collection
  #
  # @param data [Object] the data to initialize the object with
  # @return [void]
  def initialize(data)
    @facts = data.facts
    @enforcement_tolerance = data.enforcement_tolerance
    @environment_data = data.environment_data
    @collection ||= {}
    hash_key = key
    data.files.each do |file|
      data.get(file)[hash_key]&.each do |k, v|
        @collection[k] ||= collected.new(k, data: self)
        @collection[k].add(file, v)
      end
    end
  end

  attr_accessor :collection, :facts, :enforcement_tolerance, :environment_data

  def invalidate_cache(data = nil)
    @facts = data&.facts
    @enforcement_tolerance = data&.enforcement_tolerance
    @environment_data = data&.environment_data
    collection.each_value { |obj| obj.invalidate_cache(data) }
  end

  # Converts the object to a hash representation.
  #
  # @return [Hash] the hash representation of the object.
  #
  # @fixme This should implement merge behavior.
  def to_h
    # FIXME: This should implement merge behavior.
    collection.reject { |k, _| k.is_a?(Symbol) }
  end

  # Returns the keys of the collection.
  #
  # @return [Array] the keys of the collection
  def keys
    # FIXME: Implement confinement
    to_h.keys
  end

  def [](key)
    collection[key]
  end

  def each(&block)
    to_h.each(&block)
  end

  def each_value(&block)
    to_h.each_value(&block)
  end

  def any?(&block)
    to_h.any?(&block)
  end

  def all?(&block)
    to_h.all?(&block)
  end

  def select(&block)
    to_h.select(&block)
  end

  def reject(&block)
    to_h.reject(&block)
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
