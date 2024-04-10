# frozen_string_literal: true

require 'compliance_engine'

# A collection of compliance engine data CEs
class ComplianceEngine::Ces < ComplianceEngine::Collection
  # A Hash of CEs by OVAL ID
  #
  # @return [Hash]
  def by_oval_id
    return @by_oval_id unless @by_oval_id.nil?

    @by_oval_id ||= {}

    each do |k, v|
      v.oval_ids&.each do |oval_id|
        @by_oval_id[oval_id] ||= {}
        @by_oval_id[oval_id][k] = v
      end
    end

    @by_oval_id
  end

  private

  # Returns the key of the collection in compliance engine source data
  #
  # @return [String]
  def key
    'ce'
  end

  # Returns the class to use for the collection
  #
  # @return [Class]
  def collected
    ComplianceEngine::Ce
  end
end
