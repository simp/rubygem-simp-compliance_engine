# frozen_string_literal: true

require 'compliance_engine/version'
require 'compliance_engine/data'
require 'logger'

# Work with compliance data
module ComplianceEngine
  class Error < StandardError; end

  # Open compliance data
  #
  # @param [Array<String>] paths The paths to the compliance data files
  # @return [ComplianceEngine::Data]
  def self.open(*paths)
    Data.new(*paths)
  end

  # Open compliance data
  #
  # @param [Array<String>] paths The paths to the compliance data files
  # @return [ComplianceEngine::Data]
  def self.new(*paths)
    Data.new(*paths)
  end

  # Get the logger
  #
  # @return [Logger]
  def self.log
    return @log unless @log.nil?

    @log = Logger.new(STDERR)
    @log.level = Logger::WARN
    @log
  end

  # Set the logger
  # @param logger [Logger] The logger to use
  def self.log=(value)
    @log = value
  end
end
