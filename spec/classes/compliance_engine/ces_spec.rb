# frozen_string_literal: true

require 'spec_helper'
require 'compliance_engine'

RSpec.describe ComplianceEngine::Ces do
  subject(:ces) { described_class.new(ComplianceEngine::Data.new) }

  it 'initializes' do
    expect(ces).not_to be_nil
    expect(ces).to be_instance_of(described_class)
  end
end
