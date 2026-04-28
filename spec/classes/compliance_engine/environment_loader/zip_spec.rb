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

    it 'sets zipfile_path to the path' do
      expect(environment_loader.zipfile_path).to eq(path)
    end

    it 'closes the zip after initialization' do
      close_called = false
      allow(Zip::File).to receive(:open).and_wrap_original do |original, p|
        zip = original.call(p)
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
      described_class.new(path, load_dotfiles: false)
      expect(ComplianceEngine::ModuleLoader).to have_received(:new).with(anything, hash_including(load_dotfiles: false)).at_least(:once)
    end
  end

  context 'with an opened ::Zip::File' do
    subject(:environment_loader) { described_class.new(zipfile) }

    let(:path) { File.expand_path('../../../fixtures/test_environment.zip', __dir__) }
    let(:zipfile) { Zip::File.open(path) }

    before(:each) do
      allow(ComplianceEngine::ModuleLoader).to receive(:new).and_return(instance_double(ComplianceEngine::ModuleLoader))
    end

    after(:each) { zipfile.close }

    it 'initializes' do
      expect(environment_loader).to be_instance_of(described_class)
    end

    it 'defaults modulepath to the zipfile name' do
      expect(environment_loader.modulepath).to eq(zipfile.name)
      expect(environment_loader.zipfile_path).to eq(zipfile.name)
    end

    it 'loads modules from the opened zip' do
      expect(environment_loader.modules).to be_instance_of(Array)
      expect(environment_loader.modules.count).to eq(2)
    end

    it 'does not close the caller-provided zip' do
      closed_during_init = false
      allow(zipfile).to receive(:close).and_wrap_original do |original|
        closed_during_init = true
        original.call
      end
      environment_loader
      expect(closed_during_init).to be false
    end

    it 'does not call Zip::File.open' do
      allow(Zip::File).to receive(:open).and_call_original
      zipfile # materialise the let; the one permitted Zip::File.open call
      environment_loader
      expect(Zip::File).to have_received(:open).once
    end

    it 'passes load_dotfiles: true to ModuleLoader by default' do
      environment_loader
      expect(ComplianceEngine::ModuleLoader).to have_received(:new).with(anything, hash_including(load_dotfiles: true)).at_least(:once)
    end

    it 'passes load_dotfiles: false to ModuleLoader when requested' do
      described_class.new(zipfile, load_dotfiles: false)
      expect(ComplianceEngine::ModuleLoader).to have_received(:new).with(anything, hash_including(load_dotfiles: false)).at_least(:once)
    end
  end

  context 'with a valid zip and an explicit name' do
    subject(:environment_loader) { described_class.new(path, name: name) }

    let(:path) { File.expand_path('../../../fixtures/test_environment.zip', __dir__) }
    let(:name) { 'custom_name.zip' }

    before(:each) do
      allow(ComplianceEngine::ModuleLoader).to receive(:new).and_return(instance_double(ComplianceEngine::ModuleLoader))
    end

    it 'uses the explicit name for modulepath and zipfile_path' do
      expect(environment_loader.modulepath).to eq(name)
      expect(environment_loader.zipfile_path).to eq(name)
    end
  end

  context 'with an explicit name' do
    subject(:environment_loader) { described_class.new(zipfile, name: name) }

    let(:path) { File.expand_path('../../../fixtures/test_environment.zip', __dir__) }
    let(:zipfile) { Zip::File.open(path) }
    let(:name) { '/outer.zip!modules.zip' }

    before(:each) do
      allow(ComplianceEngine::ModuleLoader).to receive(:new).and_return(instance_double(ComplianceEngine::ModuleLoader))
    end

    after(:each) { zipfile.close }

    it 'uses the explicit name for modulepath and zipfile_path' do
      expect(environment_loader.modulepath).to eq(name)
      expect(environment_loader.zipfile_path).to eq(name)
    end
  end
end
