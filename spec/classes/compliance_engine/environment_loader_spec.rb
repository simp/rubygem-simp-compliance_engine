# frozen_string_literal: true

require 'spec_helper'
require 'compliance_engine'
require 'compliance_engine/environment_loader'

RSpec.describe ComplianceEngine::EnvironmentLoader do
  before(:each) do
    allow(Dir).to receive(:entries).and_call_original
  end

  context 'with no paths' do
    it 'does not initialize' do
      expect { described_class.new }.to raise_error(ArgumentError)
    end
  end

  context 'with an invalid path' do
    subject(:environment_loader) { described_class.new(path) }

    let(:path) { '/path/to/module' }

    before(:each) do
      allow(Dir).to receive(:entries).with(path).and_raise(Errno::ENOTDIR)
    end

    it 'initializes' do
      expect(environment_loader).to be_instance_of(described_class)
    end

    it 'is empty' do
      expect(environment_loader.modules).to be_empty
    end
  end

  context 'with valid paths' do
    subject(:environment_loader) { described_class.new(*paths) }

    let(:paths) { ['/path1', '/path2'] }

    before(:each) do
      allow(Dir).to receive(:entries).with('/path1').and_return(['.', '..', 'a'])
      allow(Dir).to receive(:entries).with('/path2').and_return(['.', '..', 'b'])
      allow(File).to receive(:directory?).with('/path1/a').and_return(true)
      allow(File).to receive(:directory?).with('/path2/b').and_return(true)
      allow(ComplianceEngine::ModuleLoader).to receive(:new).and_return(instance_double(ComplianceEngine::ModuleLoader))
    end

    it 'initializes' do
      expect(environment_loader).to be_instance_of(described_class)
    end

    it 'is not empty' do
      expect(environment_loader.modules).to be_instance_of(Array)
      expect(environment_loader.modules.count).to eq(2)
      expect(environment_loader.modulepath).to eq(paths)
    end
  end
end
