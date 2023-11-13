# frozen_string_literal: true

require 'spec_helper'
require 'compliance_engine'

RSpec.describe ComplianceEngine::Ce do
  subject(:ce) { described_class.new('key') }

  it 'initializes' do
    expect(ce).not_to be_nil
    expect(ce).to be_instance_of(described_class)
  end
end
