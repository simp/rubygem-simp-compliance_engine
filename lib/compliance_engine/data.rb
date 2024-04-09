# frozen_string_literal: true

require 'compliance_engine'
require 'compliance_engine/version'
require 'compliance_engine/component'
require 'compliance_engine/ce'
require 'compliance_engine/check'
require 'compliance_engine/control'
require 'compliance_engine/profile'
require 'compliance_engine/collection'
require 'compliance_engine/ces'
require 'compliance_engine/checks'
require 'compliance_engine/controls'
require 'compliance_engine/profiles'

require 'deep_merge'

# Work with compliance data
class ComplianceEngine::Data
  # @param [Array<String>] paths The paths to the compliance data files
  def initialize(*paths, facts: nil, enforcement_tolerance: nil)
    @data ||= {}
    open(*paths) unless paths.nil? || paths.empty?
    @facts = facts
    @enforcement_tolerance = enforcement_tolerance
  end

  # Setting any of these should all invalidate any cached data
  attr_reader :data, :facts, :enforcement_tolerance, :environment_data

  def data=(data)
    @data = data
    invalidate_cache
  end

  def facts=(facts)
    @facts = facts
    invalidate_cache
  end

  def enforcement_tolerance=(enforcement_tolerance)
    @enforcement_tolerance = enforcement_tolerance
    invalidate_cache
  end

  def environment_data=(environment_data)
    @environment_data = environment_data
    invalidate_cache
  end

  def invalidate_cache
    [profiles, checks, controls, ces].each { |obj| obj.invalidate_cache(self) }
    @hiera = nil
    @confines = nil
    @mapping = nil
    @check_mapping = nil
  end

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
    # FIXME: This needs to be recalculated when files are added or updated.
    # return @files unless @files.nil?
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
  # @return [ComplianceEngine::Profiles]
  def profiles
    # FIXME: This needs to be recalculated when files are added or updated.
    @profiles ||= ComplianceEngine::Profiles.new(self)
  end

  # Return a collection of CEs
  #
  # @return [ComplianceEngine::CEs]
  def ces
    # FIXME: This needs to be recalculated when files are added or updated.
    @ces ||= ComplianceEngine::Ces.new(self)
  end

  # Return a collection of checks
  #
  # @return [ComplianceEngine::Checks]
  def checks
    # FIXME: This needs to be recalculated when files are added or updated.
    @checks ||= ComplianceEngine::Checks.new(self)
  end

  # Return a collection of controls
  #
  # @return [ComplianceEngine::Controls]
  def controls
    # FIXME: This needs to be recalculated when files are added or updated.
    @controls ||= ComplianceEngine::Controls.new(self)
  end

  # Return all confines
  #
  # @return [Hash]
  def confines
    return @confines unless @confines.nil?

    @confines ||= {}

    [profiles, ces, checks, controls].each do |collection|
      collection.each_value do |v|
        v.to_a.each do |component|
          next unless component.key?('confine')
          @confines = @confines.deep_merge!(component['confine'])
        end
      end
    end

    @confines
  end

  def hiera(requested_profiles = [])
    # If we have no valid profiles, we won't have any hiera data.
    return {} if requested_profiles.empty?

    cache_key = requested_profiles.to_s

    @hiera ||= {}

    return @hiera[cache_key] if @hiera.key?(cache_key)

    valid_profiles = []
    requested_profiles.each do |profile|
      if profiles[profile].nil?
        warn "Requested profile '#{profile}' not defined"
        next
      end

      valid_profiles << profiles[profile]
    end

    # If we have no valid profiles, we won't have any hiera data.
    if valid_profiles.empty?
      @hiera[cache_key] = {}
      return @hiera[cache_key]
    end

    parameters = {}

    valid_profiles.reverse_each do |profile|
      check_mapping(profile).each_value do |check|
        parameters = parameters.deep_merge!(check.hiera)
      end
    end

    @hiera[cache_key] = parameters
  end

  def check_mapping(profile_or_ce)
    raise ArgumentError, 'Argument must be a ComplianceEngine::Profile object' unless profile_or_ce.is_a?(ComplianceEngine::Profile) || profile_or_ce.is_a?(ComplianceEngine::Ce)

    cache_key = "#{profile_or_ce.class}:#{profile_or_ce.key}"

    @check_mapping ||= {}

    return @check_mapping[cache_key] if @check_mapping.key?(cache_key)

    @check_mapping[cache_key] = checks.select do |_, check|
      mapping?(check, profile_or_ce)
    end
  end

  private

  def mapping?(check, profile_or_ce)
    raise ArgumentError, 'Argument must be a ComplianceEngine::Profile object' unless profile_or_ce.is_a?(ComplianceEngine::Profile) || profile_or_ce.is_a?(ComplianceEngine::Ce)

    @mapping ||= {}
    cache_key = [check.key, "#{profile_or_ce.class}:#{profile_or_ce.key}"].to_s
    return @mapping[cache_key] if @mapping.key?(cache_key)

    # Correlate based on CEs
    if profile_or_ce.is_a?(ComplianceEngine::Profile)
      return @mapping[cache_key] = true if correlate(check.ces, profile_or_ce.ces)
    else
      return @mapping[cache_key] = true if check.ces&.include?(profile_or_ce.key)
    end

    # Correlate based on controls
    controls = check.controls&.select { |_, v| v }&.map { |k, _| k }

    return @mapping[cache_key] = true if correlate(controls, profile_or_ce.controls)

    # Correlate based on CEs and controls
    return @mapping[cache_key] = true if profile_or_ce.is_a?(ComplianceEngine::Profile) && profile_or_ce.ces&.any? { |k, _| correlate(controls, ces[k]&.controls) }

    @mapping[cache_key] = false
  end

  def correlate(a, b)
    return false if a.nil? || b.nil?
    unless a.is_a?(Array) && b.is_a?(Hash)
      raise ComplianceEngine::Error, "Expected array and hash, got #{a.class} and #{b.class}"
    end
    return false if a.empty? || b.empty?

    a.any? { |item| b[item] }
  end

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
    { version: ComplianceEngine::Version.new(contents['version']), content: contents }
  end

  # Print debugging messages to the console.
  #
  # @param [String] msg The message to print
  def debug(msg)
    warn msg
  end
end
