# frozen_string_literal: true

require 'spec_helper'
require 'compliance_engine/data_loader'

RSpec.describe ComplianceEngine::DataLoader do
  shared_examples 'a data loader' do
    it 'initializes' do
      expect(data_loader).not_to be_nil
      expect(data_loader).to be_instance_of(described_class)
    end

    it 'has a UUID key' do
      expect(data_loader.key).not_to be_nil
      expect(data_loader.key).to be_instance_of(String)
      expect(data_loader.key).to match(%r{^Hash:[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$}i)
    end
  end

  shared_examples 'an observable' do
    it 'updates the data' do
      expect { data_loader.data = updated_data }.to change(data_loader, :data).from(initial_data).to(updated_data)
    end

    it 'notifies observers' do
      class ExampleObserver
        def initialize(object)
          object.add_observer(self, :update)
        end

        def update(data)
          @data = data
        end

        attr_accessor :data
      end

      observer = ExampleObserver.new(data_loader)
      data_loader.data = updated_data
      expect(observer.data).to be_instance_of(described_class)
      expect(observer.data.data).to eq(updated_data)
    end
  end

  context 'with no data' do
    subject(:data_loader) { described_class.new }

    let(:initial_data) { {} }
    let(:updated_data) do
      {
        'key' => 'value',
        'key2' => 'value2',
      }
    end

    it_behaves_like 'a data loader'

    it_behaves_like 'an observable'
  end

  context 'with empty hash data' do
    subject(:data_loader) { described_class.new(initial_data) }

    let(:initial_data) { {} }
    let(:updated_data) do
      {
        'key' => 'value',
        'key2' => 'value2',
      }
    end

    it_behaves_like 'a data loader'

    it_behaves_like 'an observable'
  end

  context 'with non-empty hash data' do
    subject(:data_loader) { described_class.new(initial_data) }

    let(:initial_data) { { 'key' => 'value' } }
    let(:updated_data) do
      {
        'key' => 'value',
        'key2' => 'value2',
      }
    end

    it_behaves_like 'a data loader'

    it_behaves_like 'an observable'
  end

  context 'data immutability' do
    subject(:loader) { described_class.new(nested_data) }

    let(:nested_data) do
      {
        'version' => '2.0.0',
        'ce' => {
          'some_ce' => {
            'title' => 'Some CE',
            'oval-ids' => ['oval:example:def:1'],
          },
        },
      }
    end

    it 'freezes the top-level data hash' do
      expect(loader.data).to be_frozen
    end

    it 'freezes nested hashes recursively' do
      expect(loader.data['ce']).to be_frozen
      expect(loader.data['ce']['some_ce']).to be_frozen
    end

    it 'freezes nested arrays' do
      expect(loader.data['ce']['some_ce']['oval-ids']).to be_frozen
    end

    it 'freezes string values' do
      expect(loader.data['version']).to be_frozen
      expect(loader.data['ce']['some_ce']['title']).to be_frozen
    end

    it 'interns equal string values so that only one copy is kept' do
      loader.data = {
        'checks' => {
          'check_a' => { 'ces' => ['shared_ce'.dup], 'type' => 'puppet-class-parameter'.dup },
          'check_b' => { 'ces' => ['shared_ce'.dup], 'type' => 'puppet-class-parameter'.dup },
        },
      }
      checks = loader.data['checks']
      expect(checks['check_a']['ces'].first).to be(checks['check_b']['ces'].first)
      expect(checks['check_a']['type']).to be(checks['check_b']['type'])
    end

    it 'interns string values inside containers that are already frozen' do
      loader.data = {
        'ce' => {
          'ce_a' => { 'title' => 'Shared title'.dup, 'oval-ids' => ['oval:example:def:1'.dup].freeze }.freeze,
          'ce_b' => { 'title' => 'Shared title'.dup, 'oval-ids' => ['oval:example:def:1'.dup].freeze }.freeze,
        }.freeze,
      }.freeze
      ces = loader.data['ce']
      expect(ces['ce_a']['title']).to be(ces['ce_b']['title'])
      expect(ces['ce_a']['oval-ids'].first).to be(ces['ce_b']['oval-ids'].first)
      expect(ces['ce_a']['oval-ids']).to be_frozen
    end

    it 'interns string values in unfrozen data nested inside a frozen container' do
      loader.data = {
        'ce' => {
          'ce_a' => { 'controls' => ['shared_control'.dup] },
          'ce_b' => { 'controls' => ['shared_control'.dup] },
        },
      }.freeze
      ces = loader.data['ce']
      expect(ces['ce_a']['controls'].first).to be(ces['ce_b']['controls'].first)
      expect(ces['ce_a']).to be_frozen
      expect(ces['ce_a']['controls']).to be_frozen
    end

    it 'prevents top-level mutation' do
      expect { loader.data['new_key'] = 'value' }.to raise_error(FrozenError)
    end

    it 'prevents nested mutation' do
      expect { loader.data['ce']['new_ce'] = {} }.to raise_error(FrozenError)
    end

    it 'freezes replacement data on subsequent data= calls' do
      new_data = { 'version' => '2.0.0' }
      loader.data = new_data
      expect(loader.data).to be_frozen
    end
  end

  context 'with invalid data' do
    let(:data) { 'invalid data' }

    it 'raises an error' do
      expect { described_class.new(data) }.to raise_error(ComplianceEngine::Error, 'Data must be a hash')
    end
  end

  context 'update with invalid data' do
    subject(:data_loader) { described_class.new(initial_data) }

    let(:initial_data) { { 'key' => 'value' } }
    let(:updated_data) { 'invalid data' }

    it_behaves_like 'a data loader'

    it 'does not update the data' do
      expect { data_loader.data = updated_data }.to raise_error(ComplianceEngine::Error, 'Data must be a hash')
      expect(data_loader.data).to eq(initial_data)
    end
  end
end
