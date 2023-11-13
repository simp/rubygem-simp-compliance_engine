# frozen_string_literal: true

require 'spec_helper'
require 'compliance_engine'

RSpec.describe ComplianceEngine::Controls do
  subject(:controls) { described_class.new(ComplianceEngine::Data.new) }

  it 'initializes' do
    expect(controls).not_to be_nil
    expect(controls).to be_instance_of(described_class)
  end
end
