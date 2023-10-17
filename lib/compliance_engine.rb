# frozen_string_literal: true

require 'compliance_engine/version'
require 'compliance_engine/data'

module ComplianceEngine
  class Error < StandardError; end
  class ComplianceEngine < ComplianceEngine::Data; end

  # @data ||= {}

  def self.open(paths = [Dir.pwd])
    ComplianceEngine.new(paths)
  end
  # def self.open(args)
  #   ComplianceEngine::Data.new(args)
  # end

  def self.new(paths = [Dir.pwd])
    ComplianceEngine.new(paths)
  end
  # def self.new
  #   ComplianceEngine::Data.new(args)
  # end
end
