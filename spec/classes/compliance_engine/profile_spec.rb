# frozen_string_literal: true

require 'spec_helper'
require 'compliance_engine'

RSpec.describe ComplianceEngine::Profile do
  subject(:profile) { described_class.new('key') }

  it 'initializes' do
    expect(profile).not_to be_nil
    expect(profile).to be_instance_of(described_class)
  end
end
