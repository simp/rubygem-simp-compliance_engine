# frozen_string_literal: true

module ComplianceEngine
  # Validates the version field found in compliance data files.
  # Currently only version 2.0.0 of the data format is supported.
  class DataVersion
    def initialize(version)
      raise 'Missing version' if version.nil?
      raise "Unsupported version '#{version}'" unless version == '2.0.0'

      @version = version
    end

    # @return [String]
    def to_s
      @version
    end
  end
end
