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
  # @return [Logger, ComplianceEngine::PuppetLogger]
  def self.log
    return @log unless @log.nil?

    @log = Logger.new($stderr)
    @log.level = Logger::WARN
    @log
  end

  # Set the logger
  #
  # @param value [Logger, ComplianceEngine::PuppetLogger] The logger to use
  def self.log=(value)
    @log = value
  end

  # Return the path to the bundled JSON schema for SCE data files
  #
  # @return [String] absolute path to sce-schema.json
  def self.schema_path
    File.expand_path(File.join(__dir__, 'compliance_engine', 'sce-schema.json'))
  end

  # Return the parsed JSON schema for SCE data files
  #
  # @return [Hash] the parsed JSON schema
  def self.schema
    require 'json'
    @schema ||= begin
      JSON.parse(File.read(schema_path))
    rescue Errno::ENOENT, JSON::ParserError => e
      raise Error, "Failed to load schema from #{schema_path}: #{e.class}: #{e.message}"
    end
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
