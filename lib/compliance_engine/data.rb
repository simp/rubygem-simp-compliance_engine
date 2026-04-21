# frozen_string_literal: true

require_relative '../compliance_engine'
require_relative 'version'
require_relative 'component'
require_relative 'ce'
require_relative 'check'
require_relative 'control'
require_relative 'profile'
require_relative 'collection'
require_relative 'ces'
require_relative 'checks'
require_relative 'controls'
require_relative 'profiles'

require_relative 'data_loader'
require_relative 'data_loader/json'
require_relative 'data_loader/yaml'
require_relative 'module_loader'
require_relative 'environment_loader'

require 'deep_merge'
require 'json'

# Work with compliance data
class ComplianceEngine::Data
  # @param paths [Array<String>] The paths to the compliance data files
  # @param facts [Hash] The facts to use while evaluating the data
  # @param enforcement_tolerance [Integer] The tolerance to use while evaluating the data
  def initialize(*paths, facts: nil, enforcement_tolerance: nil)
    @data = {}
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

  # Ensure that cloned/duped objects get independent collection instances.
  #
  # Ruby's default clone/dup is a shallow copy, so the collection instance
  # variables (@ces, @profiles, @checks, @controls) would otherwise point to
  # the same objects as the source.  When facts= is later called on either the
  # source or the clone, invalidate_cache propagates facts into the shared
  # collection, causing the other object to silently adopt the wrong facts.
  #
  # Nilling the collection variables here forces each clone to lazily rebuild
  # its own collections the first time they are accessed, using its own context
  # (facts, enforcement_tolerance, etc.).  Cache variables that depend on those
  # collections are cleared for the same reason.
  #
  # @return [NilClass]
  def initialize_copy(_source)
    super
    # Give each clone its own outer @data hash and its own per-file inner
    # hashes so that new files opened on one clone (via open/update) are not
    # visible to other clones or the source, and so that a loader refresh on
    # the source (which mutates the inner hash in-place via Data#update) does
    # not silently affect a clone that has not yet built its lazy collections.
    # The inner per-file content values (read-only parsed data) stay shared.
    #
    # :loader is additionally cleared (set to nil) so the copy does not hold
    # a reference to the source's DataLoader object.  If it did, the copy
    # calling update(key_string) for an already-known file would invoke
    # loader.refresh, which notifies the source (the registered Observable
    # observer) and overwrites source.data[key][:content] while the copy's
    # inner hash stays stale.  With :loader nil the copy creates its own
    # independent loader (and registers itself as observer) on next access.
    @data = @data.transform_values { |entry| entry.merge(loader: nil) }
    collection_variables.each { |var| instance_variable_set(var, nil) }
    cache_variables.each { |var| instance_variable_set(var, nil) }
    nil
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
        new_keys = path.files.to_set(&:key)
        module_prefix = if path.zipfile_path
                          ::File.join(path.zipfile_path, '.', path.path)
                        else
                          path.path
                        end
        stale_keys = data.keys.select { |k| k.start_with?(module_prefix) && !new_keys.include?(k) }
        stale_keys.each { |k| data.delete(k) }
        path.files.each { |file_loader| update(file_loader) }
        reset_collection unless stale_keys.empty?
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

      # Register as an observer only when no loader is currently attached.
      # Checking the :loader value (rather than key presence) is important
      # after clone/dup: initialize_copy sets :loader to nil so the copy does
      # not share the source's loader, but the key still exists.  Checking
      # key presence would see the nil as "already registered" and skip
      # add_observer, leaving the copy deaf to future loader refreshes.
      unless data[filename.key][:loader]
        data[filename.key][:loader] = filename
        data[filename.key][:loader].add_observer(self, :update)
      end
      data[filename.key][:version] = ComplianceEngine::Version.new(filename.data['version'])
      data[filename.key][:content] = filename.data
    end

    reset_collection
  rescue StandardError => e
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
  rescue StandardError
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
    raise ComplianceEngine::Error, "Expected array and hash, got #{a.class} and #{b.class}" unless a.is_a?(Array) && b.is_a?(Hash)
    return false if a.empty? || b.empty?

    a.any? { |item| b[item] }
  end
end
