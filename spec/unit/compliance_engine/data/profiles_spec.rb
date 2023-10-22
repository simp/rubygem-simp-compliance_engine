# frozen_string_literal: true

require 'spec_helper'
require 'compliance_engine'

RSpec.describe ComplianceEngine::Data::Profiles do
  subject(:profiles) { described_class.new(ComplianceEngine::Data.new) }

  it 'initializes' do
    expect(profiles).not_to be_nil
    expect(profiles).to be_instance_of(described_class)
  end
end
