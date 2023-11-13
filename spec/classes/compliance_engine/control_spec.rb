# frozen_string_literal: true

require 'spec_helper'
require 'compliance_engine'

RSpec.describe ComplianceEngine::Control do
  subject(:control) { described_class.new('key') }

  it 'initializes' do
    expect(control).not_to be_nil
    expect(control).to be_instance_of(described_class)
  end
end
