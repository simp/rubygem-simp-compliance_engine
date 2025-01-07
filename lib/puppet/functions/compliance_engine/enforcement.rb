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

  require 'compliance_engine/data'

  def enforcement(key, options, context)
    require 'pry-byebug'; binding.pry
    # hiera(key)
  end
end
