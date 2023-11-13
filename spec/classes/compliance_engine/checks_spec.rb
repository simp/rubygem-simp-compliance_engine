# frozen_string_literal: true

require 'spec_helper'
require 'compliance_engine'

RSpec.describe ComplianceEngine::Checks do
  subject(:checks) { described_class.new(ComplianceEngine::Data.new) }

  it 'initializes' do
    expect(checks).not_to be_nil
    expect(checks).to be_instance_of(described_class)
  end
end
