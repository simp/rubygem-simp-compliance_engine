# frozen_string_literal: true

require 'compliance_engine'

# A generic compliance engine data collection
module ComplianceEngine
  class Data
    class Collection
      # A generic compliance engine data collection
      def initialize(data)
        @collection ||= {}
        data.files.each do |file|
          data.get(file)['profiles']&.each do |key, value|
            @collection[key] ||= collected.new(key)
            @collection[key].add(value)
          end
        end
      end

      attr_accessor :collection

      def to_h
        # FIXME: This should implement merge behavior.
        collection
      end

      def keys
        # FIXME: Implement confinement
        collection.keys
      end

      private

      def key
        raise NotImplementedError
      end

      def collected
        raise NotImplementedError
      end
    end
  end
end
