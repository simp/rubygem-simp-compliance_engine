# frozen_string_literal: true

require 'compliance_engine'

# A generic compliance engine data component
module ComplianceEngine
  class Data
    class Component
      # A generic compliance engine data component
      #
      # @param [String] component The component key
      def initialize(component)
        @component ||= { key: component, fragments: [] }
      end

      def add(value)
        @component[:fragments] << value
      end

      def to_h
        # FIXME: This should implement merge behavior.
        @component[:fragments]
      end
    end
  end
end
