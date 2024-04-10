# frozen_string_literal: true

require 'compliance_engine'
require 'deep_merge'

# A generic compliance engine data component
class ComplianceEngine::Component
  # A generic compliance engine data component
  #
  # @param [String] component The component key
  # @param [ComplianceEngine::Data, ComplianceEngine::Collection, NilClass] data The data to initialize the object with
  def initialize(name, data: nil)
    unless data.nil?
      @facts = data.facts
      @enforcement_tolerance = data.enforcement_tolerance
      @environment_data = data.environment_data
    end
    @component ||= { key: name, fragments: {} }
  end

  attr_accessor :component, :facts, :enforcement_tolerance, :environment_data, :cache

  # Invalidate all cached data
  #
  # @param data [ComplianceEngine::Data, ComplianceEngine::Collection, NilClass] the data to initialize the object with
  # @return [NilClass]
  def invalidate_cache(data = nil)
    @facts = data&.facts
    @enforcement_tolerance = data&.enforcement_tolerance
    @environment_data = data&.environment_data
    @fragments = nil
    @cache = nil
  end

  # Adds a value to the fragments array of the component.
  #
  # @param value [Object] The value to be added to the fragments array.
  # @return [Object]
  def add(filename, value)
    component[:fragments][filename] = value
  end

  # Returns an array of fragments from the component.
  #
  # @return [Array] an array of fragments
  def to_a
    component[:fragments].values
  end

  # Returns an array of fragments from the component.
  #
  # @return [Array] an array of fragments
  def to_h
    # TODO: Return confined & deep-merged data
  end

  # Returns the key of the component
  #
  # @return [String] the key of the component
  def key
    component[:key]
  end

  # Returns the title of the component
  #
  # @return [String] the title of the component
  def title
    element('title')
  end

  # Returns the description of the component
  #
  # @return [String] the description of the component
  def description
    element('description')
  end

  # Returns the oval ids of the component
  #
  # @return [Array] the oval ids of the component
  def oval_ids
    element('oval-ids')
  end

  # Returns the controls of the component
  #
  # @return [Hash] the controls of the component
  def controls
    element('controls')
  end

  # Returns the identifiers of the component
  #
  # @return [Hash] the identifiers of the component
  def identifiers
    element('identifiers')
  end

  # Returns the ces of the component
  #
  # @return [Array, Hash] the ces of the component
  # @note This returns an Array for checks and a Hash for other components
  def ces
    element('ces')
  end

  private

  # Compare a fact value against a confine value
  #
  # @param [Object] fact The fact value
  # @param [Object] confine The confine value
  # @param [Integer] depth The depth of the recursion
  # @return [TrueClass, FalseClass] true if the fact value matches the confine value
  def fact_match?(fact, confine, depth = 0)
    if confine.is_a?(String)
      return fact != confine.delete_prefix('!') if confine.start_with?('!')

      fact == confine
    elsif confine.is_a?(Array)
      if depth == 0
        confine.any? { |value| fact_match?(fact, value, depth + 1) }
      else
        fact == confine
      end
    else
      fact == confine
    end
  end

  # Check if a fragment is confined
  #
  # @param [Hash] fragment The fragment to check
  # @return [TrueClass, FalseClass] true if the fragment should be dropped
  def confine_away?(fragment)
    return false unless fragment.key?('confine')

    fragment['confine'].each do |k, v|
      if k == 'module_name'
        # TODO: Implement confinement based on Puppet environment data
        unless environment_data.nil?
          # FIXME: Puppet environment data is not yet supported
          # module_version = fragment['confine']['module_version']
        end
      elsif k == 'module_version'
        warn "Missing module name for #{fragment}" unless fragment['confine'].key?('module_name')
      else
        # Confinement based on Puppet facts
        unless facts.nil?
          fact = facts.dig(*k.split('.'))
          if fact.nil?
            warn "Fact #{k} not found for #{fragment}"
            return true
          end
          unless fact_match?(fact, v)
            warn "Fact #{k} #{fact} does not match #{v} for #{fragment}"
            return true
          end
        end
      end
    end

    false
  end

  # Returns the fragments of the component after confinement
  #
  # @return [Hash] the fragments of the component
  def fragments
    return @fragments unless @fragments.nil?

    @fragments ||= {}

    component[:fragments].each do |filename, fragment|
      # If none of the confinable data is present in the object,
      # ignore confinement data entirely.
      if facts.nil? && enforcement_tolerance.nil? && environment_data.nil?
        @fragments[filename] = fragment
        next
      end

      # If no confine data is present in the fragment, include it.
      if !fragment.key?('confine') && !fragment.key?('remediation')
        @fragments[filename] = fragment
        next
      end

      next if confine_away?(fragment)

      # Confinement based on remediation risk
      if enforcement_tolerance.is_a?(Integer) && is_a?(ComplianceEngine::Check) && fragment.key?('remediation')
        if fragment['remediation'].key?('disabled')
          message = "Remediation disabled for #{fragment}"
          reason = fragment['remediation']['disabled']&.map { |value| value['reason'] }&.reject { |value| value.nil? }&.join("\n")
          message += "\n#{reason}" unless reason.nil?
          warn message
          next
        end

        if fragment['remediation'].key?('risk')
          risk_level = fragment['remediation']['risk']&.map { |value| value['level'] }&.select { |value| value.is_a?(Integer) }&.max
          if risk_level.is_a?(Integer) && risk_level >= enforcement_tolerance
            warn "Remediation risk #{risk_level} exceeds enforcement tolerance #{enforcement_tolerance} for #{fragment}"
            next
          end
        end
      end

      @fragments[filename] = fragment
    end

    @fragments
  end

  # Returns an element of the component
  #
  # @param [String] key The key of the element
  # @return [Object] the element of the component
  def element(key)
    return cache[key] if cache&.key?(key)

    cache ||= {}

    fragments.each_value do |fragment|
      next unless fragment.key?(key)

      if fragment[key].is_a?(Array)
        cache[key] ||= []
        cache[key] += fragment[key]
      elsif fragment[key].is_a?(Hash)
        cache[key] ||= {}
        cache[key] = cache[key].deep_merge!(fragment[key])
      else
        cache[key] = fragment[key]
      end
    end

    cache[key]
  end
end
