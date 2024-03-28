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

      # TODO: Implement confinement based on Puppet facts
      if fragment.key?('confine')
      end

      # TODO: Implement confinement based on Puppet enviroment data
      if fragment.key?('confine') && fragment['confine'].key?('module_name')
      end

      # TODO: Implement confinement based on remediation risk
      if fragment.key?('remediation')
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
