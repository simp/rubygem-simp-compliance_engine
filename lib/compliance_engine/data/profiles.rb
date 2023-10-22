# frozen_string_literal: true

require 'compliance_engine'

# A collection of compliance engine data profiles
module ComplianceEngine
  class Data
    class Profiles < ComplianceEngine::Data::Collection
      private

      def key
        'profiles'
      end

      def collected
        Profile
      end
    end
  end
end
