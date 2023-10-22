# frozen_string_literal: true

require 'compliance_engine'

# Handle supported compliance data versions
module ComplianceEngine
  class Data
    class Version
      # Verify that the version is supported
      #
      # @param [String] version The version to verify
      def initialize(version)
        raise Error, 'Missing version' if version.nil?
        raise Error, "Unsupported version '#{version}'" unless version == '2.0.0'
        @version = version
      end

      def to_s
        @version
      end
    end
  end
end
