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

require 'compliance_engine/data_loader'
require 'compliance_engine/data_loader/json'
require 'compliance_engine/data_loader/yaml'
require 'compliance_engine/module_loader'
require 'compliance_engine/environment_loader'

require 'deep_merge'
require 'json'

# Work with compliance data
class ComplianceEngine::Data
  # @param paths [Array<String>] The paths to the compliance data files
  # @param facts [Hash] The facts to use while evaluating the data
  # @param enforcement_tolerance [Integer] The tolerance to use while evaluating the data
  def initialize(*paths, facts: nil, enforcement_tolerance: nil)
    @data ||= {}
    @facts = facts
    @enforcement_tolerance = enforcement_tolerance
    open(*paths) unless paths.nil? || paths.empty?
  end

  # Setting any of these should all invalidate any cached data
  attr_reader :data, :facts, :enforcement_tolerance, :environment_data, :modulepath

  # Set the object data
  # @param data [Hash] The data to initialize the object with
  def data=(value)
    @data = value
    invalidate_cache
  end

  # Set the facts
  # @param facts [Hash] The facts to initialize the object with
  def facts=(value)
    @facts = value
    invalidate_cache
  end

  # Set the enforcement tolerance
  # @param enforcement_tolerance [Hash] The enforcement tolerance to initialize
  def enforcement_tolerance=(value)
    @enforcement_tolerance = value
    invalidate_cache
  end

  # Set the environment data
  # @param environment_data [Hash] The environment data to initialize the object with
  def environment_data=(value)
    @environment_data = value
    invalidate_cache
  end

  # Set the modulepath
  # @param modulepath [Array<String>] The Puppet modulepath
  def modulepath=(value)
    @modulepath = value
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

  # Scan a Puppet environment from a zip file
  # @param path [String] The Puppet environment archive file
  # @return [NilClass]
  def open_environment_zip(path)
    require 'compliance_engine/environment_loader/zip'

    environment = ComplianceEngine::EnvironmentLoader::Zip.new(path)
    self.modulepath = environment.modulepath
    open(environment)
  end

  # Scan a Puppet environment
  # @param paths [Array<String>] The Puppet modulepath components
  # @return [NilClass]
  def open_environment(*paths)
    environment = ComplianceEngine::EnvironmentLoader.new(*paths)
    self.modulepath = environment.modulepath
    open(environment)
  end

  # Scan paths for compliance data files
  #
  # @param paths [Array<String>] The paths to the compliance data files
  # @param fileclass [Class] The class to use for reading files
  # @param dirclass [Class] The class to use for reading directories
  # @return [NilClass]
  def open(*paths, fileclass: File, dirclass: Dir)
    modules = {}

    paths.each do |path|
      if path.is_a?(ComplianceEngine::EnvironmentLoader)
        open(*path.modules)
        next
      end

      if path.is_a?(ComplianceEngine::ModuleLoader)
        modules[path.name] = path.version unless path.name.nil?
        path.files.each do |file_loader|
          update(file_loader)
        end
        next
      end

      if path.is_a?(ComplianceEngine::DataLoader)
        update(path, key: path.key, fileclass: fileclass)
        next
      end

      if fileclass.file?(path)
        update(path, key: path.to_s, fileclass: fileclass)
        next
      end

      if fileclass.directory?(path)
        open(ComplianceEngine::ModuleLoader.new(path, fileclass: fileclass, dirclass: dirclass))
        next
      end

      raise ComplianceEngine::Error, "Invalid path or object '#{path}'"
    end

    self.environment_data ||= {}
    self.environment_data = self.environment_data.merge(modules)

    nil
  end

  # Update the data for a given file
  #
  # @param file [String] The path to the compliance data file
  # @param key [String] The key to use for the data
  # @param fileclass [Class] The class to use for reading files
  # @param size [Integer] The size of the file
  # @param mtime [Time] The modification time of the file
  # @return [NilClass]
  def update(
    filename,
    key: filename.to_s,
    fileclass: File
  )
    if filename.is_a?(String)
      data[key] ||= {}

      if data[key]&.key?(:loader) && data[key][:loader]
        data[key][:loader].refresh if data[key][:loader].respond_to?(:refresh)
        return
      end

      loader = if File.extname(filename) == '.json'
                 ComplianceEngine::DataLoader::Json.new(filename, fileclass: fileclass, key: key)
               else
                 ComplianceEngine::DataLoader::Yaml.new(filename, fileclass: fileclass, key: key)
               end

      loader.add_observer(self, :update)
      data[key] = {
        loader: loader,
        version: ComplianceEngine::Version.new(loader.data['version']),
        content: loader.data,
      }
    else
      data[filename.key] ||= {}

      # Assume filename is a loader object
      unless data[filename.key]&.key?(:loader)
        data[filename.key][:loader] = filename
        data[filename.key][:loader].add_observer(self, :update)
      end
      data[filename.key][:version] = ComplianceEngine::Version.new(filename.data['version'])
      data[filename.key][:content] = filename.data
    end

    reset_collection
  rescue => e
    ComplianceEngine.log.error e.message
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
  # @param file [String] The path to the compliance data file
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
          @confines = DeepMerge.deep_merge!(component['confine'], @confines)
        end
      end
    end

    @confines
  end

  # Return all Hiera data from checks that map to the requested profiles
  #
  # @param requested_profiles [Array<String>] The requested profiles
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
        ComplianceEngine.log.error "Requested profile '#{profile}' not defined"
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
        parameters = DeepMerge.deep_merge!(check.hiera, parameters)
      end
    end

    @hiera[cache_key] = parameters
  end

  # Return all checks that map to the requested profile or CE
  #
  # @param profile_or_ce [ComplianceEngine::Profile, ComplianceEngine::Ce] The requested profile or CE
  # @return [Hash]
  def check_mapping(profile_or_ce)
    raise ArgumentError, 'Argument must be a ComplianceEngine::Profile object' unless profile_or_ce.is_a?(ComplianceEngine::Profile) || profile_or_ce.is_a?(ComplianceEngine::Ce)

    cache_key = "#{profile_or_ce.class}:#{profile_or_ce.key}"

    @check_mapping ||= {}

    return @check_mapping[cache_key] if @check_mapping.key?(cache_key)

    @check_mapping[cache_key] = checks.select do |_, check|
      mapping?(check, profile_or_ce) && !filtered_by_tolerance?(check)
    end
  end

  private

  # Check if a check should be filtered out based on enforcement tolerance
  #
  # @param check [ComplianceEngine::Check] The check to evaluate
  # @return [TrueClass, FalseClass] true if check should be filtered out
  def filtered_by_tolerance?(check)
    return false if enforcement_tolerance.nil?

    remediation = check.remediation
    return false if remediation.nil?

    # Filter out disabled checks
    return true if remediation['disabled']

    # Filter based on risk level
    if remediation['risk']&.is_a?(Array) && !remediation['risk'].empty?
      risk_level = remediation['risk'][0]['level']
      if risk_level && enforcement_tolerance.to_i > 0
        return risk_level.to_i > enforcement_tolerance.to_i
      end
    end

    false
  end

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
    [:@enforcement_tolerance, :@environment_data, :@facts, :@modulepath]
  end

  # Get the cache variables
  #
  # @return [Array<Symbol>]
  def cache_variables
    instance_variables - (data_variables + collection_variables + context_variables)
  end

  # Return true if the check is mapped to the profile or CE
  #
  # @param check [ComplianceEngine::Check] The check
  # @param profile_or_ce [ComplianceEngine::Profile, ComplianceEngine::Ce] The profile or CE
  # @return [TrueClass, FalseClass]
  def mapping?(check, profile_or_ce)
    raise ArgumentError, 'Argument must be a ComplianceEngine::Profile object' unless profile_or_ce.is_a?(ComplianceEngine::Profile) || profile_or_ce.is_a?(ComplianceEngine::Ce)

    @mapping ||= {}
    cache_key = [check.key, "#{profile_or_ce.class}:#{profile_or_ce.key}"].to_s
    return @mapping[cache_key] if @mapping.key?(cache_key)

    # Correlate based on controls
    controls = check.controls&.select { |_, v| v }&.map { |k, _| k }

    return @mapping[cache_key] = true if correlate(controls, profile_or_ce.controls)

    if profile_or_ce.is_a?(ComplianceEngine::Ce)
      # Correlate based on CEs
      return @mapping[cache_key] = true if check.ces&.include?(profile_or_ce.key)

      return @mapping[cache_key] = false
    end

    # Correlate based on direct reference to checks
    return @mapping[cache_key] = true if profile_or_ce.checks&.dig(check.key)

    # Correlate based on CEs
    return @mapping[cache_key] = true if correlate(check.ces, profile_or_ce.ces)

    # Correlate based on CEs and controls
    return @mapping[cache_key] = true if profile_or_ce.ces&.any? { |k, _| correlate(controls, ces[k]&.controls) }
    return @mapping[cache_key] = true if check.ces&.any? { |ce| ces[ce]&.controls&.any? { |k, v| v && profile_or_ce.controls&.dig(k) } }

    @mapping[cache_key] = false
  end

  # Correlate between arrays and hashes
  #
  # @param a [Array] An array
  # @param b [Hash] A hash
  # @return [TrueClass, FalseClass]
  def correlate(a, b)
    return false if a.nil? || b.nil?
    unless a.is_a?(Array) && b.is_a?(Hash)
      raise ComplianceEngine::Error, "Expected array and hash, got #{a.class} and #{b.class}"
    end
    return false if a.empty? || b.empty?

    a.any? { |item| b[item] }
  end
end
