# frozen_string_literal: true

require 'compliance_engine'

# A generic compliance engine data collection
class ComplianceEngine::Collection
  # A generic compliance engine data collection
  #
  # @param data [ComplianceEngine::Data] the data to initialize the object with
  def initialize(data)
    context_variables.each { |var| instance_variable_set(var, data.instance_variable_get(var)) }
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

  # Invalidate the cache of computed data
  #
  # @param data [ComplianceEngine::Data, NilClass] the data to initialize the object with
  # @return [NilClass]
  def invalidate_cache(data = nil)
    context_variables.each { |var| instance_variable_set(var, data&.instance_variable_get(var)) }
    collection.each_value { |obj| obj.invalidate_cache(data) }
    (instance_variables - (context_variables + [:@collection])).each { |var| instance_variable_set(var, nil) }
    nil
  end

  # Converts the object to a hash representation
  #
  # @return [Hash] the hash representation of the object
  def to_h
    collection.reject { |k, _| k.is_a?(Symbol) }
  end

  # Returns the keys of the collection
  #
  # @return [Array] the keys of the collection
  def keys
    to_h.keys
  end

  # Return a single value from the collection
  #
  # @param key [String] the key of the value to return
  # @return [Object] the value of the key
  def [](key)
    collection[key]
  end

  # Iterates over the collection
  #
  # @param block [Proc] the block to execute
  def each(&block)
    to_h.each(&block)
  end

  # Iterates over values in the collection
  #
  # @param block [Proc] the block to execute
  def each_value(&block)
    to_h.each_value(&block)
  end

  # Iterates over keys in the collection
  #
  # @param block [Proc] the block to execute
  def each_key(&block)
    to_h.each_key(&block)
  end

  # Return true if any of the values in the collection match the block
  #
  # @param block [Proc] the block to execute
  # @return [TrueClass, FalseClass] true if any of the values in the collection match the block
  def any?(&block)
    to_h.any?(&block)
  end

  # Return true if all of the values in the collection match the block
  #
  # @param block [Proc] the block to execute
  # @return [TrueClass, FalseClass] true if all of the values in the collection match the block
  def all?(&block)
    to_h.all?(&block)
  end

  # Select values in the collection
  #
  # @param block [Proc] the block to execute
  # @return [Hash] the filtered hash
  def select(&block)
    to_h.select(&block)
  end

  # Filter out values in the collection
  #
  # @param block [Proc] the block to execute
  # @return [Hash] the filtered hash
  def reject(&block)
    to_h.reject(&block)
  end

  private

  # Get the context variables
  #
  # @return [Array<Symbol>]
  def context_variables
    %i[@enforcement_tolerance @environment_data @facts]
  end

  # Returns the key of the object
  #
  # @return [NotImplementedError] This method is not implemented and should be overridden by subclasses.
  def key
    raise NotImplementedError
  end

  # Returns the class to use for the collection
  #
  # @return [NotImplementedError] This method is not implemented and should be overridden by subclasses.
  def collected
    raise NotImplementedError
  end
end
