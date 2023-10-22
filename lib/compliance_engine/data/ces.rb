# frozen_string_literal: true

require 'compliance_engine'

# A collection of compliance engine data CEs
module ComplianceEngine
  class Data
    class Ces < ComplianceEngine::Data::Collection
      private

      def key
        'ce'
      end

      def collected
        Ce
      end
    end
  end
end
