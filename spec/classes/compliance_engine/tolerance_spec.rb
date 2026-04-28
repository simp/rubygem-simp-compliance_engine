# frozen_string_literal: true

require 'spec_helper'
require 'compliance_engine'

RSpec.describe ComplianceEngine::Tolerance do
  it { expect(described_class::NONE).to eq(20) }
  it { expect(described_class::SAFE).to eq(40) }
  it { expect(described_class::MODERATE).to eq(60) }
  it { expect(described_class::ACCESS).to eq(80) }
  it { expect(described_class::BREAKING).to eq(100) }

  it 'has constants in ascending order' do
    levels = [
      described_class::NONE,
      described_class::SAFE,
      described_class::MODERATE,
      described_class::ACCESS,
      described_class::BREAKING,
    ]
    expect(levels).to eq(levels.sort)
  end
end
