# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceEngine do
  it 'has a version number' do
    expect(ComplianceEngine::VERSION).not_to be_nil
  end

  it 'initializes' do
    compliance_engine = described_class.new
    expect(compliance_engine).not_to be_nil
    expect(compliance_engine).to be_instance_of(ComplianceEngine::ComplianceEngine)
  end
end
