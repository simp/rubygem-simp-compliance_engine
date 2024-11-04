# frozen_string_literal: true

require 'spec_helper'
require 'compliance_engine/data_loader/json'

RSpec.describe ComplianceEngine::DataLoader::Json do
  before(:each) do
    allow(File).to receive(:read).and_call_original
  end

  shared_examples 'a data loader' do
    it 'initializes' do
      expect(data_loader).not_to be_nil
      expect(data_loader).to be_instance_of(described_class)
    end

    it 'has the filename for the key' do
      expect(data_loader.key).not_to be_nil
      expect(data_loader.key).to be_instance_of(String)
      expect(data_loader.key).to eq(filename)
    end
  end

  shared_examples 'an observable' do
    it 'updates the data' do
      data_loader.refresh
      expect(data_loader.data).to eq(updated_data)
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
      data_loader.refresh
      expect(observer.data).to be_instance_of(described_class)
      expect(observer.data.data).to eq(updated_data)
    end
  end

  context 'with no data' do
    subject(:data_loader) { described_class.new(filename) }

    let(:filename) { '/path/to/file' }
    let(:initial_data) { {} }
    let(:updated_data) do
      {
        'key' => 'value',
        'key2' => 'value2',
      }
    end

    before(:each) do
      allow(File).to receive(:read).with(filename).and_return(initial_data.to_json)
    end

    it_behaves_like 'a data loader'

    context 'with updated data' do
      before(:each) do
        allow(File).to receive(:read).with(filename).and_return(updated_data.to_json)
      end

      it_behaves_like 'an observable'
    end
  end

  context 'with empty hash data' do
    subject(:data_loader) { described_class.new(filename) }

    let(:filename) { '/path/to/file' }
    let(:initial_data) { {} }
    let(:updated_data) do
      {
        'key' => 'value',
        'key2' => 'value2',
      }
    end

    before(:each) do
      allow(File).to receive(:read).with(filename).and_return(initial_data.to_json)
    end

    it_behaves_like 'a data loader'

    context 'with updated data' do
      before(:each) do
        allow(File).to receive(:read).with(filename).and_return(updated_data.to_json)
      end

      it_behaves_like 'an observable'
    end
  end

  context 'with non-empty hash data' do
    subject(:data_loader) { described_class.new(filename) }

    let(:filename) { '/path/to/file' }
    let(:initial_data) { { 'key' => 'value' } }
    let(:updated_data) do
      {
        'key' => 'value',
        'key2' => 'value2',
      }
    end

    before(:each) do
      allow(File).to receive(:read).with(filename).and_return(initial_data.to_json)
    end

    it_behaves_like 'a data loader'

    context 'with updated data' do
      before(:each) do
        allow(File).to receive(:read).with(filename).and_return(updated_data.to_json)
      end

      it_behaves_like 'an observable'
    end
  end

  context 'with invalid data' do
    let(:filename) { '/path/to/file' }
    let(:data) { 'invalid data' }

    before(:each) do
      allow(File).to receive(:read).with(filename).and_return(data.to_json)
    end

    it 'raises an error' do
      expect { described_class.new(filename) }.to raise_error(ComplianceEngine::Error, 'Data must be a hash')
    end
  end

  context 'update with invalid data' do
    let(:filename) { '/path/to/file' }
    let(:initial_data) { { 'key' => 'value' } }
    let(:updated_data) { 'invalid data' }

    before(:each) do
      allow(File).to receive(:read).with(filename).and_return(initial_data.to_json)
    end

    it 'does not update the data' do
      loader = described_class.new(filename)

      allow(File).to receive(:read).with(filename).and_return(updated_data.to_json)

      expect { loader.refresh }.to raise_error(ComplianceEngine::Error, 'Data must be a hash')
      expect(loader.data).to eq(initial_data)
    end
  end
end
