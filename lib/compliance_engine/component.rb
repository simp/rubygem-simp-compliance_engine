# frozen_string_literal: true

require 'compliance_engine'
require 'deep_merge'

# A generic compliance engine data component
class ComplianceEngine::Component
  # A generic compliance engine data component
  #
  # @param [String] component The component key
  def initialize(name, data: nil)
    unless data.nil?
      @facts = data.facts
      @enforcement_tolerance = data.enforcement_tolerance
      @environment_data = data.environment_data
    end
    @component ||= { key: name, fragments: [] }
  end

  attr_accessor :component, :facts, :enforcement_tolerance, :environment_data

  def invalidate_cache(data)
    @facts = data.facts
    @enforcement_tolerance = data.enforcement_tolerance
    @environment_data = data.environment_data
    @fragments = nil
  end

  # Adds a value to the fragments array of the component.
  #
  # @param value [Object] The value to be added to the fragments array.
  # @return [void]
  def add(value)
    component[:fragments] << value
  end

  # Returns an array of fragments from the component.
  #
  # @return [Array] an array of fragments
  def to_a
    component[:fragments]
  end

  # Returns an array of fragments from the component.
  #
  # @return [Array] an array of fragments
  def to_h
    # TODO: Return confined & deep-merged data
  end

  def key
    component[:key]
  end

  def title
    element(:title, 'title')
  end

  def description
    element(:description, 'description')
  end

  def oval_ids
    element(:oval_ids, 'oval-ids')
  end

  def controls
    element(:controls, 'controls')
  end

  def identifiers
    element(:identifiers, 'identifiers')
  end

  def ces
    element(:ces, 'ces')
  end

  private

  def fact_match?(fact, confine)
    if confine.is_a?(String)
      return fact != confine.delete_prefix('!') if confine.start_with?('!')

      fact == confine
    elsif confine.is_a?(Array)
      confine.any? { |value| fact_match?(fact, value) }
    else
      fact == confine
    end
  end

  def confine_away?(fragment)
    return false unless fragment.key?('confine')

    fragment['confine'].each do |k, v|
      if k == 'module_name'
        # TODO: Implement confinement based on Puppet environment data
        unless environment_data.nil?
          module_version = fragment['confine']['module_version']
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

  def fragments
    return @fragments unless @fragments.nil?

    @fragments ||= []

    component[:fragments].each do |fragment|
      # If none of the confinable data is present in the object,
      # ignore confinement data entirely.
      if facts.nil? && enforcement_tolerance.nil? && environment_data.nil?
        @fragments << fragment
        next
      end

      # If no confine data is present in the fragment, include it.
      if !fragment.key?('confine') && !fragment.key?('remediation')
        @fragments << fragment
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

      @fragments << fragment
    end

    @fragments
  end

  def element(key, value)
    return component[key] if component.key?(key)

    fragments.each do |fragment|
      next unless fragment.key?(value)

      if fragment[value].is_a?(Array)
        component[key] ||= []
        component[key] += fragment[value]
      elsif fragment[value].is_a?(Hash)
        component[key] ||= {}
        component[key] = component[key].deep_merge!(fragment[value])
      else
        component[key] = fragment[value]
      end
    end

    component[key]
  end
end
