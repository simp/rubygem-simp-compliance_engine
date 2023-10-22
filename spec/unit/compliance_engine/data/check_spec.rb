# frozen_string_literal: true

require 'spec_helper'
require 'compliance_engine'

RSpec.describe ComplianceEngine::Data::Check do
  subject(:check) { described_class.new('key') }

  it 'initializes' do
    expect(check).not_to be_nil
    expect(check).to be_instance_of(described_class)
  end
end
