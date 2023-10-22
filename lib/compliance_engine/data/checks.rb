# frozen_string_literal: true

require 'compliance_engine'

# A collection of compliance engine data checks
module ComplianceEngine
  class Data
    class Checks < ComplianceEngine::Data::Collection
      private

      def key
        'checks'
      end

      def collected
        Check
      end
    end
  end
end
