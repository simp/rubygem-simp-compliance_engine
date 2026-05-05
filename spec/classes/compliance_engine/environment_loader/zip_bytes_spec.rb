# frozen_string_literal: true

require 'spec_helper'
require 'compliance_engine'
require 'compliance_engine/environment_loader/zip_bytes'

RSpec.describe ComplianceEngine::EnvironmentLoader::ZipBytes do
  before(:each) do
    allow(Dir).to receive(:entries).and_call_original
  end

  context 'with no arguments' do
    it 'does not initialize' do
      expect { described_class.new }.to raise_error(ArgumentError)
    end
  end

  context 'with a non-String input' do
    it 'raises ArgumentError for any non-String' do
      expect { described_class.new(42) }.to raise_error(ArgumentError, /must be a String/)
      expect { described_class.new(nil) }.to raise_error(ArgumentError, /must be a String/)
    end
  end

  context 'with invalid bytes' do
    it 'does not initialize' do
      expect { described_class.new('not a zip') }.to raise_error(Zip::Error)
    end
  end

  context 'with valid bytes' do
    subject(:environment_loader) { described_class.new(bytes) }

    let(:path) { File.expand_path('../../../fixtures/test_environment.zip', __dir__) }
    let(:bytes) { File.binread(path) }

    before(:each) do
      allow(ComplianceEngine::ModuleLoader).to receive(:new).and_return(instance_double(ComplianceEngine::ModuleLoader))
    end

    it 'initializes' do
      expect(environment_loader).to be_instance_of(described_class)
    end

    it 'is not empty' do
      expect(environment_loader.modules).to be_instance_of(Array)
      expect(environment_loader.modules.count).to eq(2)
    end

    it 'defaults modulepath to "-"' do
      expect(environment_loader.modulepath).to eq('-')
    end

    it 'sets zipfile_path to "-"' do
      expect(environment_loader.zipfile_path).to eq('-')
    end

    it 'closes the zip after initialization' do
      close_called = false
      allow(Zip::File).to receive(:open_buffer).and_wrap_original do |original, b|
        zip = original.call(b)
        allow(zip).to(receive(:close).and_wrap_original do |m, *args|
          close_called = true
          m.call(*args)
        end)
        zip
      end
      environment_loader
      expect(close_called).to be true
    end

    it 'passes load_dotfiles: true to ModuleLoader by default' do
      environment_loader
      expect(ComplianceEngine::ModuleLoader).to have_received(:new).with(anything, hash_including(load_dotfiles: true)).at_least(:once)
    end

    it 'passes load_dotfiles: false to ModuleLoader when requested' do
      described_class.new(bytes, load_dotfiles: false)
      expect(ComplianceEngine::ModuleLoader).to have_received(:new).with(anything, hash_including(load_dotfiles: false)).at_least(:once)
    end
  end

  context 'with valid bytes and an explicit name' do
    subject(:environment_loader) { described_class.new(bytes, name: name) }

    let(:path) { File.expand_path('../../../fixtures/test_environment.zip', __dir__) }
    let(:bytes) { File.binread(path) }
    let(:name) { 'custom_name.zip' }

    before(:each) do
      allow(ComplianceEngine::ModuleLoader).to receive(:new).and_return(instance_double(ComplianceEngine::ModuleLoader))
    end

    it 'uses the explicit name for modulepath and zipfile_path' do
      expect(environment_loader.modulepath).to eq(name)
      expect(environment_loader.zipfile_path).to eq(name)
    end
  end
end
