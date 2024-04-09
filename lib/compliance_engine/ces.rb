# frozen_string_literal: true

require 'compliance_engine'

# A collection of compliance engine data CEs
class ComplianceEngine::Ces < ComplianceEngine::Collection
  def by_oval_id
    return @by_oval_id unless @by_oval_id.nil?

    @by_oval_id ||= {}

    to_h.each do |k, v|
      v.oval_ids&.each do |oval_id|
        @by_oval_id[oval_id] ||= []
        @by_oval_id[oval_id] << k
      end
    end

    @by_oval_id.each_key { |k| @by_oval_id[k].uniq! }
    @by_oval_id
  end

  private

  def key
    'ce'
  end

  def collected
    ComplianceEngine::Ce
  end
end
