# frozen_string_literal: true

# @summary Hiera entry point for Compliance Engine
Puppet::Functions.create_function(:'compliance_engine::enforcement') do
  # @param key String The key to lookup in the Hiera data
  # @return [String] The value of the key in the Hiera data
  dispatch :enforcement do
    param 'String[1]', :key
    param 'Hash[String[1], Any]', :options
    param 'Puppet::LookupContext', :context
  end

  require 'compliance_engine'

  def enforcement(key, options, context)
    ComplianceEngine.log.level = Logger::DEBUG

    @compat = options['compliance_markup_compatibility']

    case key
    when 'lookup_options'
      return context.not_found
    when %r{^compliance_(?:engine|markup)::}
      return context.not_found
    else
      return context.interpolate(context.cached_value(key)) if context.cache_has_key(key)
    end

    # If we have no profiles to work with, we can't do anything.
    return context.not_found if profiles.empty?

    if context.cache_has_key(:compliance_engine)
      ComplianceEngine.log.debug('Using cached ComplianceEngine::Data object')
      data = context.cached_value(:compliance_engine)
    else
      data = ComplianceEngine::Data.new
      data.facts = closure_scope.lookupvar('facts')
      data.enforcement_tolerance = enforcement_tolerance || options['enforcement_tolerance']
      data.open(ComplianceEngine::EnvironmentLoader.new(*closure_scope.environment.full_modulepath.select { |path| File.directory?(path) }))

      data.open(ComplianceEngine::DataLoader.new(compliance_map)) unless compliance_map.empty?
      context.cache(:compliance_engine, data)
    end

    context.cache_all(data.hiera(profiles))

    return context.interpolate(context.cached_value(key)) if context.cache_has_key(key)

    # if data.hiera(profiles).key?(key)
    #   context.cache(key, data.hiera(profiles)[key])
    #   return context.interpolate(data.hiera(profiles)[key])
    # end

    context.not_found
  rescue StandardError => e
    # Log any exceptions that occur
    ComplianceEngine.log.error("Error in compliance_engine::enforcement: #{e.message}")
    ComplianceEngine.log.error(e.backtrace.join("\n"))
    raise
  end

  def profiles
    profile_list = call_function('lookup', 'compliance_engine::enforcement', { 'default_value' => [] })

    # For backwards compatibility with compliance_markup.
    profile_list += call_function('lookup', 'compliance_markup::enforcement', { 'default_value' => [] }) if @compat

    profile_list.uniq
  end

  def compliance_map
    hiera_compliance_map = call_function('lookup', 'compliance_engine::compliance_map', { 'default_value' => {} })

    # For backwards compatibility with compliance_markup.
    hiera_compliance_map = DeepMerge.deep_merge!(call_function('lookup', 'compliance_markup::compliance_map', { 'default_value' => {} }), hiera_compliance_map) if @compat

    hiera_compliance_map
  end

  def enforcement_tolerance
    tolerance = call_function('lookup', 'compliance_engine::enforcement_tolerance', { 'default_value' => nil })

    # For backwards compatibility with compliance_markup.
    tolerance = call_function('lookup', 'compliance_markup::enforcement_tolerance_level', { 'default_value' => nil }) if @compat && tolerance.nil?

    tolerance
  end
end
