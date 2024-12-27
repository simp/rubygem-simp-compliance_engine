# frozen_string_literal: true

require 'spec_helper'
require 'compliance_engine'
require 'compliance_engine/environment_loader/zip'

RSpec.describe ComplianceEngine::EnvironmentLoader::Zip do
  before(:each) do
    allow(Dir).to receive(:entries).and_call_original
  end

  context 'with no paths' do
    it 'does not initialize' do
      expect { described_class.new }.to raise_error(ArgumentError)
    end
  end

  context 'with an invalid zip' do
    subject(:environment_loader) { described_class.new(path) }

    let(:path) { '/path/to/module.zip' }

    before(:each) do
      allow(Zip::File).to receive(:open).with(path).and_raise(Zip::Error)
    end

    it 'does not initialize' do
      expect { described_class.new(path) }.to raise_error(Zip::Error)
    end
  end

  context 'with a valid zip' do
    subject(:environment_loader) { described_class.new(path) }

    let(:path) { File.expand_path('../../../fixtures/test_environment.zip', __dir__) }

    before(:each) do
      allow(ComplianceEngine::ModuleLoader).to receive(:new).and_return(instance_double(ComplianceEngine::ModuleLoader))
    end

    it 'initializes' do
      expect(environment_loader).to be_instance_of(described_class)
    end

    it 'is not empty' do
      expect(environment_loader.modules).to be_instance_of(Array)
      expect(environment_loader.modules.count).to eq(2)
      expect(environment_loader.modulepath).to eq(path)
    end
  end
end
