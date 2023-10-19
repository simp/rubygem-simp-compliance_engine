# frozen_string_literal: true

require 'spec_helper'
require 'compliance_engine'

RSpec.describe ComplianceEngine::Data do
  before(:each) do
    allow(File).to receive(:directory?).and_call_original
    allow(File).to receive(:file?).and_call_original
    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:mtime).and_call_original
    allow(File).to receive(:size).and_call_original
  end

  context 'with no paths' do
    subject(:compliance_engine) { described_class.new }

    it 'initializes' do
      expect(compliance_engine).not_to be_nil
      expect(compliance_engine).to be_instance_of(described_class)
    end
  end

  context 'with an empty directory path' do
    subject(:compliance_engine) { described_class.new('test_module_00') }

    before(:each) do
      allow(File).to receive(:directory?).with('test_module_00').and_return(true)
    end

    it 'initializes' do
      expect(compliance_engine).not_to be_nil
      expect(compliance_engine).to be_instance_of(described_class)
    end
  end

  context 'with multiple empty directory paths' do
    subject(:compliance_engine) { described_class.new('test_module_00', 'test_module_01') }

    before(:each) do
      allow(File).to receive(:directory?).with('test_module_00').and_return(true)
      allow(File).to receive(:directory?).with('test_module_01').and_return(true)
    end

    it 'initializes' do
      expect(compliance_engine).not_to be_nil
      expect(compliance_engine).to be_instance_of(described_class)
    end
  end

  context 'with a non-existent path' do
    before(:each) do
      allow(File).to receive(:directory?).with('non_existant').and_return(false)
      allow(File).to receive(:file?).with('non_existant').and_return(false)
    end

    it 'fails to initialize' do
      expect { described_class.new('non_existant') }.to raise_error(ComplianceEngine::Error, %r{Could not find path})
    end
  end

  context 'with a yaml file path' do
    subject(:compliance_engine) { described_class.new('file.yaml') }

    before(:each) do
      allow(File).to receive(:directory?).with('file.yaml').and_return(false)
      allow(File).to receive(:file?).with('file.yaml').and_return(true)
      allow(File).to receive(:size).with('file.yaml').and_return(18)
      allow(File).to receive(:mtime).with('file.yaml').and_return(Time.now)
      allow(File).to receive(:read).with('file.yaml').and_return("---\nversion: 2.0.0")
    end

    it 'initializes' do
      expect(compliance_engine).not_to be_nil
      expect(compliance_engine).to be_instance_of(described_class)
    end

    it 'returns a list of files' do
      expect(compliance_engine.files).to eq(['file.yaml'])
    end

    it 'get returns a hash' do
      expect(compliance_engine.get('file.yaml')).to eq({ 'version' => '2.0.0' })
    end
  end

  context 'with a malformed file path' do
    subject(:compliance_engine) { described_class.new('file') }

    before(:each) do
      allow(File).to receive(:directory?).with('file').and_return(false)
      allow(File).to receive(:file?).with('file').and_return(true)
      allow(File).to receive(:size).with('file').and_return(0)
      allow(File).to receive(:mtime).with('file').and_return(Time.now)
      allow(File).to receive(:read).with('file').and_return('')
    end

    it 'initializes' do
      expect(compliance_engine).not_to be_nil
      expect(compliance_engine).to be_instance_of(described_class)
    end

    it 'returns an empty list of files' do
      expect(compliance_engine.files).to eq([])
    end

    it 'get returns nil' do
      expect(compliance_engine.get('file')).to be_nil
    end
  end
end
