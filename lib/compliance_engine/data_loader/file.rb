# frozen_string_literal: true

require 'compliance_engine'
require 'compliance_engine/data_loader'

# Load compliance engine data from a file
class ComplianceEngine::DataLoader::File < ComplianceEngine::DataLoader
  def initialize(file, fileclass: ::File, key: file)
    @fileclass = fileclass
    @filename = file
    @size = fileclass.size(file)
    @mtime = fileclass.mtime(file)
    super(parse(fileclass.read(file)), key: key)
  end

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
