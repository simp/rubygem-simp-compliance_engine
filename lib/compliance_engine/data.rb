# frozen_string_literal: true

require 'compliance_engine'
require 'compliance_engine/data/version'
require 'compliance_engine/data/component'
require 'compliance_engine/data/ce'
require 'compliance_engine/data/check'
require 'compliance_engine/data/control'
require 'compliance_engine/data/profile'
require 'compliance_engine/data/collection'
require 'compliance_engine/data/ces'
require 'compliance_engine/data/checks'
require 'compliance_engine/data/controls'
require 'compliance_engine/data/profiles'

# Work with compliance data
class ComplianceEngine::Data
  # @param [Array<String>] paths The paths to the compliance data files
  def initialize(*paths)
    @data ||= {}
    open(*paths) unless paths.nil? || paths.empty?
  end

  attr_accessor :data

  # Scan paths for compliance data files
  #
  # @param [Array<String>] paths The paths to the compliance data files
  def open(*paths)
    paths.each do |path|
      if File.directory?(path)
        # In this directory, we want to look for all yaml and json files
        # under SIMP/compliance_profiles and simp/compliance_profiles.
        globs = ['SIMP/compliance_profiles', 'simp/compliance_profiles']
                .select { |dir| Dir.exist?("#{path}/#{dir}") }
                .map { |dir|
          ['yaml', 'json'].map { |type| "#{path}/#{dir}/**/*.#{type}" }
        }.flatten
        # debug "Globs: #{globs}"
        # Using .each here to make mocking with rspec easier.
        Dir.glob(globs).each do |file|
          update(file)
        end
      elsif File.file?(path)
        update(path)
      else
        raise ComplianceEngine::Error, "Could not find path '#{path}'"
      end
    end
  end

  # Update the data for a given file
  #
  # @param [String] file The path to the compliance data file
  def update(file)
    # debug "Scanning #{file}"
    # If we've already scanned this file, and the size and modification
    # time of the file haven't changed, skip it.
    size = File.size(file)
    mtime = File.mtime(file)
    if data.key?(file) && data[file][:size] == size && data[file][:mtime] == mtime
      return
    end

    data[file] = {
      size: size,
      mtime: mtime,
    }

    begin
      data[file] = parse(file)
    rescue => e
      warn e.message
    end
  end

  # Get a list of files with compliance data
  #
  # @return [Array<String>]
  def files
    return @files unless @files.nil?
    @files = data.select { |_file, data| data.key?(:content) }.keys
  end

  # Get the compliance data for a given file
  #
  # @param [String] file The path to the compliance data file
  # @return [Hash]
  def get(file)
    data[file][:content]
  rescue
    nil
  end

  # Return a profile collection
  #
  # @return [ComplianceEngine::Data::Profiles]
  def profiles
    @profiles ||= Profiles.new(self)
  end

  # Return a collection of CEs
  #
  # @return [ComplianceEngine::Data::CEs]
  def ces
    @ces ||= Ces.new(self)
  end

  # Return a collection of checks
  #
  # @return [ComplianceEngine::Data::Checks]
  def checks
    @checks ||= Checks.new(self)
  end

  # Return a collection of controls
  #
  # @return [ComplianceEngine::Data::Controls]
  def controls
    @controls ||= Controls.new(self)
  end

  # Return all confines
  #
  # @return [Hash]
  def confines
    return @confines unless @confines.nil?

    require 'deep_merge'

    @confines ||= {}

    [profiles, ces, checks, controls].each do |collection|
      # require 'pry-byebug'; binding.pry
      collection.to_h.each do |_, v|
        v.to_a.each do |component|
          next unless component.key?('confine')
          @confines = @confines.deep_merge!(component['confine'])
        end
      end
    end

    @confines
  end

  private

  # Parse YAML or JSON files
  #
  # @param [String] file The path to the compliance data file
  # @return [Hash]
  def parse(file)
    contents = if File.extname(file) == '.json'
                 require 'json'
                 JSON.parse(File.read(file))
               else
                 require 'yaml'
                 YAML.safe_load(File.read(file))
               end
    raise ComplianceEngine::Error, "File must contain a hash, found #{contents.class} in #{file}" unless contents.is_a?(Hash)
    { version: Version.new(contents['version']), content: contents }
  end

  # Print debugging messages to the console.
  #
  # @param [String] msg The message to print
  def debug(msg)
    warn msg
  end
end
