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
      expect(data_loader.key).to match(%r{^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$}i)
    end
  end

  shared_examples 'an observable' do
    it 'updates the data' do
      expect { data_loader.data = updated_data }.to change { data_loader.data }.from(initial_data).to(updated_data)
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
