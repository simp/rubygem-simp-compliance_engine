# frozen_string_literal: true

require_relative '../compliance_engine'

module ComplianceEngine
  # Validates the version field found in compliance data files.
  # Currently only version 2.0.0 of the data format is supported.
  class DataVersion
    def initialize(version)
      raise ComplianceEngine::Error, 'Missing version' if version.nil?
      raise ComplianceEngine::Error, "Unsupported version '#{version}'" unless version == '2.0.0'

      @version = version
    end

    # @return [String]
    def to_s
      @version
    end
  end
end
