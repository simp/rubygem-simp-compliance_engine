# frozen_string_literal: true

require 'spec_helper'
require 'compliance_engine'

RSpec.describe ComplianceEngine::Collection do
  subject(:collection) { described_class.new(ComplianceEngine::Data.new) }

  it 'does not initialize' do
    expect { collection }.to raise_error(NotImplementedError)
  end

  describe 'changing context after data has been computed' do
    subject(:checks) { data.checks }

    let(:data) do
      ComplianceEngine::Data.new(
        ComplianceEngine::DataLoader.new(
          {
            'version' => '2.0.0',
            'checks' => {
              'linux_check' => {
                'type' => 'puppet-class-parameter',
                'settings' => { 'parameter' => 'example::param', 'value' => true },
                'confine' => { 'kernel' => 'Linux' },
                'remediation' => { 'risk' => [{ 'level' => 40 }] },
              },
            },
          },
        ),
        facts: { 'kernel' => 'Linux' },
      )
    end

    before(:each) do
      # Compute and cache the merged data with the original context.
      checks['linux_check'].to_h
    end

    it 'passes new facts on to its components' do
      checks.facts = { 'kernel' => 'Darwin' }
      expect(checks['linux_check'].facts).to eq({ 'kernel' => 'Darwin' })
      expect(checks['linux_check'].type).to be_nil
    end

    it 'passes a new enforcement tolerance on to its components' do
      checks.enforcement_tolerance = 30
      expect(checks['linux_check'].enforcement_tolerance).to eq(30)
      expect(checks['linux_check'].type).to be_nil
    end

    it 'passes new environment data on to its components' do
      checks.environment_data = { 'author-module' => '1.0.0' }
      expect(checks['linux_check'].environment_data).to eq({ 'author-module' => '1.0.0' })
    end

    it 'does not change the Data object it was built from' do
      checks.facts = { 'kernel' => 'Darwin' }
      expect(data.facts).to eq({ 'kernel' => 'Linux' })
    end
  end
end
