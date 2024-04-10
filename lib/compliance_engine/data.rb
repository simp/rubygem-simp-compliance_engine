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

  # Set the object data
  # @param [Hash] data The data to initialize the object with
  def data=(value)
    @data = value
    invalidate_cache
  end

  # Set the facts
  # @param [Hash] facts The facts to initialize the object with
  def facts=(value)
    @facts = value
    invalidate_cache
  end

  # Set the enforcement tolerance
  # @param [Hash] enforcement_tolerance The enforcement tolerance to initialize
  def enforcement_tolerance=(value)
    @enforcement_tolerance = value
    invalidate_cache
  end

  # Set the environment data
  # @param [Hash] environment_data The environment data to initialize the object with
  def environment_data=(value)
    @environment_data = value
    invalidate_cache
  end

  # Invalidate the cache of computed data
  #
  # @return [NilClass]
  def invalidate_cache
    collection_variables.each { |var| instance_variable_get(var)&.invalidate_cache(self) }
    cache_variables.each { |var| instance_variable_set(var, nil) }
  end

  # Discard all parsed data other than the top-level data
  #
  # @return [NilClass]
  def reset_collection
    # Discard any cached objects
    (instance_variables - (data_variables + context_variables)).each { |var| instance_variable_set(var, nil) }
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
    # If we've already scanned this file, and the size and modification
    # time of the file haven't changed, skip it.
    size = File.size(file)
    mtime = File.mtime(file)
    if data.key?(file) && data[file][:size] == size && data[file][:mtime] == mtime
      return
    end

    data[file] = begin
                   parse(file)
                 rescue => e
                   warn e.message
                   {}
                 end

    data[file][:size] = size
    data[file][:mtime] = mtime

    reset_collection
  end

  # Get a list of files with compliance data
  #
  # @return [Array<String>]
  def files
    return @files unless @files.nil?
    @files = data.select { |_, file| file.key?(:content) }.keys
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
    @profiles ||= ComplianceEngine::Profiles.new(self)
  end

  # Return a collection of CEs
  #
  # @return [ComplianceEngine::CEs]
  def ces
    @ces ||= ComplianceEngine::Ces.new(self)
  end

  # Return a collection of checks
  #
  # @return [ComplianceEngine::Checks]
  def checks
    @checks ||= ComplianceEngine::Checks.new(self)
  end

  # Return a collection of controls
  #
  # @return [ComplianceEngine::Controls]
  def controls
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

  # Return all Hiera data from checks that map to the requested profiles
  #
  # @param [Array<String>] requested_profiles The requested profiles
  # @return [Hash]
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

  # Return all checks that map to the requested profile or CE
  #
  # @param [ComplianceEngine::Profile, ComplianceEngine::Ce] profile_or_ce The requested profile or CE
  # @return [Hash]
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

  # Get the collection variables
  #
  # @return [Array<Symbol>]
  def collection_variables
    [:@profiles, :@checks, :@controls, :@ces]
  end

  # Get the data variables
  #
  # @return [Array<Symbol>]
  def data_variables
    [:@data]
  end

  # Get the context variables
  #
  # @return [Array<Symbol>]
  def context_variables
    [:@enforcement_tolerance, :@environment_data, :@facts]
  end

  # Get the cache variables
  #
  # @return [Array<Symbol>]
  def cache_variables
    instance_variables - (data_variables + collection_variables + context_variables)
  end

  # Return true if the check is mapped to the profile or CE
  #
  # @param [ComplianceEngine::Check] check The check
  # @param [ComplianceEngine::Profile, ComplianceEngine::Ce] profile_or_ce The profile or CE
  # @return [TrueClass, FalseClass]
  def mapping?(check, profile_or_ce)
    raise ArgumentError, 'Argument must be a ComplianceEngine::Profile object' unless profile_or_ce.is_a?(ComplianceEngine::Profile) || profile_or_ce.is_a?(ComplianceEngine::Ce)

    @mapping ||= {}
    cache_key = [check.key, "#{profile_or_ce.class}:#{profile_or_ce.key}"].to_s
    return @mapping[cache_key] if @mapping.key?(cache_key)

    # Correlate based on CEs
    if profile_or_ce.is_a?(ComplianceEngine::Profile) && correlate(check.ces, profile_or_ce.ces)
      return @mapping[cache_key] = true
    elsif check.ces&.include?(profile_or_ce.key)
      return @mapping[cache_key] = true
    end

    # Correlate based on controls
    controls = check.controls&.select { |_, v| v }&.map { |k, _| k }

    return @mapping[cache_key] = true if correlate(controls, profile_or_ce.controls)

    # Correlate based on CEs and controls
    return @mapping[cache_key] = true if profile_or_ce.is_a?(ComplianceEngine::Profile) && profile_or_ce.ces&.any? { |k, _| correlate(controls, ces[k]&.controls) }

    @mapping[cache_key] = false
  end

  # Correlate between arrays and hashes
  #
  # @param [Array] a An array
  # @param [Hash] b A hash
  # @return [TrueClass, FalseClass]
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
