# frozen_string_literal: true

module ComplianceEngine
  VERSION = '0.2.0'

  # Handle supported compliance data versions
  class Version
    # Verify that the version is supported
    #
    # @param version [String] The version to verify
    def initialize(version)
      raise 'Missing version' if version.nil?
      raise "Unsupported version '#{version}'" unless version == '2.0.0'
      @version = version
    end

    # Convert the version to a string
    #
    # @return [String]
    def to_s
      @version
    end
  end
end
