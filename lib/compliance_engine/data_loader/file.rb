# frozen_string_literal: true

require 'compliance_engine'
require 'compliance_engine/data_loader'

# Load compliance engine data from a file
class ComplianceEngine::DataLoader::File < ComplianceEngine::DataLoader
  # Initialize a new instance of the ComplianceEngine::DataLoader::File class
  #
  # @param file [String] The path to the file to be loaded
  # @param fileclass [Class] The class to use for file operations, defaults to `::File`
  # @param key [String] The key to use for identifying the data, defaults to the file path
  def initialize(file, fileclass: ::File, key: file)
    @fileclass = fileclass
    @filename = file
    @size = fileclass.size(file)
    @mtime = fileclass.mtime(file)
    super(parse(fileclass.read(file)), key: key)
  end

  # Refresh the data from the file if it has changed
  #
  # @return [NilClass]
  def refresh
    newsize = @fileclass.size(@filename)
    newmtime = @fileclass.mtime(@filename)
    return if newsize == @size && newmtime == @mtime

    @size = newsize
    @mtime = newmtime
    self.data = parse(@fileclass.read(@filename))
  end

  attr_reader :key, :size, :mtime
end
