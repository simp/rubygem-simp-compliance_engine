# frozen_string_literal: true

require 'compliance_engine'

# A collection of compliance engine data controls
module ComplianceEngine
  class Data
    class Controls < ComplianceEngine::Data::Collection
      private

      def key
        'controls'
      end

      def collected
        Control
      end
    end
  end
end
