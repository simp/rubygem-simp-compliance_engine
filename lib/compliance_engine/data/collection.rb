# frozen_string_literal: true

require 'compliance_engine'

# A generic compliance engine data collection
module ComplianceEngine
  class Data
    class Collection
      # A generic compliance engine data collection
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
