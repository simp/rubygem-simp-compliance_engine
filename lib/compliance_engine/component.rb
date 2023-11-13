# frozen_string_literal: true

require 'compliance_engine'

# A generic compliance engine data component
class ComplianceEngine::Component
  # A generic compliance engine data component
  #
  # @param [String] component The component key
  def initialize(component)
    @component ||= { key: component, fragments: [] }
  end

  # Adds a value to the fragments array of the component.
  #
  # @param value [Object] The value to be added to the fragments array.
  # @return [void]
  def add(value)
    @component[:fragments] << value
  end

  # Returns an array of fragments from the component.
  #
  # @return [Array] an array of fragments
  def to_a
    @component[:fragments]
  end
end
