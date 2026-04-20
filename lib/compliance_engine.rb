# frozen_string_literal: true

require_relative 'compliance_engine/version'
require_relative 'compliance_engine/data'
require 'logger'

# Work with compliance data
module ComplianceEngine
  class Error < StandardError; end

  # Open compliance data
  #
  # @param paths [Array<String>] The paths to the compliance data files
  # @return [ComplianceEngine::Data]
  def self.open(*paths)
    Data.new(*paths)
  end

  # Open compliance data
  #
  # @param paths [Array<String>] The paths to the compliance data files
  # @return [ComplianceEngine::Data]
  def self.new(*paths)
    Data.new(*paths)
  end

  # Get the logger
  #
  # @return [Logger]
  def self.log
    return @log unless @log.nil?

    @log = Logger.new($stderr)
    @log.level = Logger::WARN
    @log
  end

  # Set the logger
  # @param logger [Logger] The logger to use
  def self.log=(value)
    @log = value
  end

  # Install a PuppetLogger unless a logger has already been explicitly configured.
  # Extracted so the behaviour can be unit-tested without reloading enforcement.rb.
  #
  # @return [void]
  def self.install_puppet_logger
    return unless @log.nil?

    require_relative 'compliance_engine/puppet_logger'
    @log = PuppetLogger.new
  end
end
