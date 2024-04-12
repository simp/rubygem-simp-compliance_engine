# frozen_string_literal: true

require 'spec_helper'
require 'compliance_engine'

RSpec.describe ComplianceEngine::Check do
  subject(:check) { described_class.new('key') }

  it 'initializes' do
    expect(check).not_to be_nil
    expect(check).to be_instance_of(described_class)
  end

  context 'with data' do
    let(:test_data) do
      {
        'file0' => { 'merge_key' => ['value0'] },
        'file1' => { 'merge_key' => ['value1'], 'confine' => { 'kernel' => ['Linux'] } },
        'file2' => { 'merge_key' => ['value2'], 'confine' => { 'kernel' => ['windows'] } },
        'file3' => { 'merge_key' => ['value3'], 'confine' => { 'module_name' => 'author-module' } },
        'file4' => { 'merge_key' => ['value4'], 'confine' => { 'module_name' => 'author-module', 'module_version' => '>= 1.0.0 < 2.0.0' } },
        'file5' => { 'merge_key' => ['value5'], 'remediation' => { 'disabled' => [ { 'reason' => 'anything' } ], 'risk' => [ { 'level' => 1 } ] } },
        'file6' => { 'merge_key' => ['value6'], 'remediation' => { 'risk' => [ { 'level' => 21 } ] } },
        'file7' => { 'merge_key' => ['value7'], 'remediation' => { 'risk' => [ { 'level' => 41 } ] } },
      }
    end

    before(:each) do
      test_data.each do |key, value|
        check.add(key, value)
      end
    end

    it 'accepts data' do
      expect(check.to_a).to be_a(Array)
      expect(check.to_a.size).to eq test_data.keys.size
    end

    context 'without confinement' do
      it 'returns merged data' do
        expect(check.to_h).to be_a(Hash)
        expect(check.to_h['merge_key']).to eq(test_data.values.map { |v| v['merge_key'] }.flatten)
      end
    end

    context 'with facts' do
      before(:each) do
        check.invalidate_cache
      end

      it 'includes expected values' do
        check.facts = { 'kernel' => 'Linux' }
        expect(check.to_h).to be_a(Hash)
        expect(check.to_h['merge_key']).to include('value0')
        expect(check.to_h['merge_key']).to include('value1')
        expect(check.to_h['merge_key']).not_to include('value2')
      end

      it 'excludes expected values' do
        check.facts = { 'kernel' => 'Darwin' }
        expect(check.to_h).to be_a(Hash)
        expect(check.to_h['merge_key']).to include('value0')
        expect(check.to_h['merge_key']).not_to include('value1')
        expect(check.to_h['merge_key']).not_to include('value2')
      end
    end

    context 'with environment data' do
      before(:each) do
        check.invalidate_cache
      end

      it 'excludes values based on module name' do
        check.environment_data = { 'unknown_author-other_module' => '1.0.0' }
        expect(check.to_h).to be_a(Hash)
        expect(check.to_h['merge_key']).to include('value0')
        expect(check.to_h['merge_key']).not_to include('value3')
        expect(check.to_h['merge_key']).not_to include('value4')
      end

      it 'includes a value based on module name' do
        check.environment_data = { 'author-module' => '0.1.0' }
        expect(check.to_h).to be_a(Hash)
        expect(check.to_h['merge_key']).to include('value0')
        expect(check.to_h['merge_key']).to include('value3')
        expect(check.to_h['merge_key']).not_to include('value4')
      end

      it 'includes a value based on module name and version' do
        check.environment_data = { 'author-module' => '1.1.0' }
        expect(check.to_h).to be_a(Hash)
        expect(check.to_h['merge_key']).to include('value0')
        expect(check.to_h['merge_key']).to include('value3')
        expect(check.to_h['merge_key']).to include('value4')
      end
    end

    context 'with enforcement tolerance' do
      before(:each) do
        check.invalidate_cache
      end

      it 'excludes disabled values' do
        check.enforcement_tolerance = 30
        expect(check.to_h).to be_a(Hash)
        expect(check.to_h['merge_key']).not_to include('value5')
      end

      it 'include values with lower risk' do
        check.enforcement_tolerance = 30
        expect(check.to_h).to be_a(Hash)
        expect(check.to_h['merge_key']).to include('value6')
      end

      it 'excludes values with higher risk' do
        check.enforcement_tolerance = 30
        expect(check.to_h).to be_a(Hash)
        expect(check.to_h['merge_key']).not_to include('value7')
      end
    end
  end
end
