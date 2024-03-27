# frozen_string_literal: true

require 'compliance_engine'
require 'deep_merge'

# A generic compliance engine data component
class ComplianceEngine::Component
  # A generic compliance engine data component
  #
  # @param [String] component The component key
  def initialize(name)
    @component ||= { key: name, fragments: [] }
  end

  attr_accessor :component

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

  def element(key, value)
    return component[key] if component.key?(key)

    component[:fragments].each do |fragment|
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
