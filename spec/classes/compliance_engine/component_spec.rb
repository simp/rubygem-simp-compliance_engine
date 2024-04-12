# frozen_string_literal: true

require 'spec_helper'
require 'compliance_engine'

RSpec.describe ComplianceEngine::Component do
  subject(:component) { described_class.new('key') }

  it 'initializes' do
    expect(component).not_to be_nil
    expect(component).to be_instance_of(described_class)
  end

  context 'with data' do
    let(:test_data) do
      {
        'file0' => { 'merge_key' => ['value0'] },
        'file1' => { 'merge_key' => ['value1'], 'confine' => { 'kernel' => ['Linux'] } },
        'file2' => { 'merge_key' => ['value2'], 'confine' => { 'kernel' => ['windows'] } },
        'file3' => { 'merge_key' => ['value3'], 'confine' => { 'module_name' => 'author-module' } },
        'file4' => { 'merge_key' => ['value4'], 'confine' => { 'module_name' => 'author-module', 'module_version' => '>= 1.0.0 < 2.0.0' } },
      }
    end

    before(:each) do
      test_data.each do |key, value|
        component.add(key, value)
      end
    end

    it 'accepts data' do
      expect(component.to_a).to be_a(Array)
      expect(component.to_a.size).to eq test_data.keys.size
    end

    context 'without confinement' do
      it 'returns merged data' do
        expect(component.to_h).to be_a(Hash)
        expect(component.to_h['merge_key']).to eq(test_data.values.map { |v| v['merge_key'] }.flatten)
      end
    end

    context 'with facts' do
      before(:each) do
        component.invalidate_cache
      end

      it 'includes expected values' do
        component.facts = { 'kernel' => 'Linux' }
        expect(component.to_h).to be_a(Hash)
        expect(component.to_h['merge_key']).to include('value0')
        expect(component.to_h['merge_key']).to include('value1')
        expect(component.to_h['merge_key']).not_to include('value2')
      end

      it 'excludes expected values' do
        component.facts = { 'kernel' => 'Darwin' }
        expect(component.to_h).to be_a(Hash)
        expect(component.to_h['merge_key']).to include('value0')
        expect(component.to_h['merge_key']).not_to include('value1')
        expect(component.to_h['merge_key']).not_to include('value2')
      end
    end

    context 'with environment data' do
      before(:each) do
        component.invalidate_cache
      end

      it 'excludes values based on module name' do
        component.environment_data = { 'unknown_author-other_module' => '1.0.0' }
        expect(component.to_h).to be_a(Hash)
        expect(component.to_h['merge_key']).to include('value0')
        expect(component.to_h['merge_key']).not_to include('value3')
        expect(component.to_h['merge_key']).not_to include('value4')
      end

      it 'includes a value based on module name' do
        component.environment_data = { 'author-module' => '0.1.0' }
        expect(component.to_h).to be_a(Hash)
        expect(component.to_h['merge_key']).to include('value0')
        expect(component.to_h['merge_key']).to include('value3')
        expect(component.to_h['merge_key']).not_to include('value4')
      end

      it 'includes a value based on module name and version' do
        component.environment_data = { 'author-module' => '1.1.0' }
        expect(component.to_h).to be_a(Hash)
        expect(component.to_h['merge_key']).to include('value0')
        expect(component.to_h['merge_key']).to include('value3')
        expect(component.to_h['merge_key']).to include('value4')
      end
    end
  end
end
