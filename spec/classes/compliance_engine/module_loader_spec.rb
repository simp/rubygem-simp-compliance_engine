# frozen_string_literal: true

require 'spec_helper'
require 'compliance_engine'
require 'compliance_engine/module_loader'

RSpec.describe ComplianceEngine::ModuleLoader do
  before(:each) do
    allow(File).to receive(:directory?).and_call_original
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:file?).and_call_original
    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:mtime).and_call_original
    allow(File).to receive(:size).and_call_original

    allow(Dir).to receive(:glob).and_call_original
  end

  context 'with no path' do
    it 'does not initialize' do
      expect { described_class.new }.to raise_error(ArgumentError)
    end
  end

  context 'with an invalid path' do
    let(:path) { '/path/to/module' }

    before(:each) do
      allow(File).to receive(:directory?).with(path).and_return(false)
    end

    it 'does not initialize' do
      expect { described_class.new(path) }.to raise_error(ComplianceEngine::Error, "#{path} is not a directory")
    end
  end

  context 'with no module data' do
    subject(:module_loader) { described_class.new(path) }

    let(:path) { '/path/to/module' }

    before(:each) do
      allow(File).to receive(:directory?).with(path).and_return(true)
      allow(File).to receive(:exist?).with("#{path}/metadata.json").and_return(false)
      allow(File).to receive(:directory?).with("#{path}/SIMP/compliance_profiles").and_return(false)
      allow(File).to receive(:directory?).with("#{path}/simp/compliance_profiles").and_return(false)
    end

    it 'initializes' do
      expect(module_loader).not_to be_nil
      expect(module_loader).to be_instance_of(described_class)
    end
  end

  context 'with module data' do
    subject(:module_loader) { described_class.new(test_data.keys.first) }

    let(:test_data) do
      {
        'test_module_00' => {
          'a/file.yaml' => <<~A_YAML,
            ---
            version: '2.0.0'
            profiles:
              test_profile_00:
                ces:
                  ce_00: true
              test_profile_01:
                ces:
                  ce_01: true
            ce:
              ce_00: {}
              ce_01: {}
            A_YAML
          'b/file.yaml' => <<~B_YAML,
            ---
            version: '2.0.0'
            profiles:
              test_profile_01:
                ces:
                  ce_02: true
            ce:
              ce_02: {}
            B_YAML
          'c/file.yaml' => <<~C_YAML,
            ---
            version: '2.0.0'
            profiles:
              test_profile_02:
                ces:
                  ce_03: true
            ce:
              ce_03: {}
            C_YAML
        },
      }
    end

    before(:each) do
      test_data.each do |module_path, file_data|
        allow(File).to receive(:directory?).with(module_path).and_return(true)
        allow(File).to receive(:directory?).with("#{module_path}/SIMP/compliance_profiles").and_return(true)
        allow(File).to receive(:directory?).with("#{module_path}/simp/compliance_profiles").and_return(false)
        allow(Dir).to receive(:glob)
          .with("#{module_path}/SIMP/compliance_profiles/**/*.yaml")
          .and_return(
            file_data.map { |name, _contents| "#{module_path}/SIMP/compliance_profiles/#{name}" },
          )
        allow(Dir).to receive(:glob)
          .with("#{module_path}/SIMP/compliance_profiles/**/*.json")
          .and_return([])

        file_data.each do |name, contents|
          filename = "#{module_path}/SIMP/compliance_profiles/#{name}"
          allow(File).to receive(:size).with(filename).and_return(contents.length)
          allow(File).to receive(:mtime).with(filename).and_return(Time.now)
          allow(File).to receive(:read).with(filename).and_return(contents)
        end
      end
    end

    context 'with no metadata.json' do
      before(:each) do
        allow(File).to receive(:exist?).with("#{test_data.keys.first}/metadata.json").and_return(false)
      end

      it 'initializes' do
        expect(module_loader).not_to be_nil
        expect(module_loader).to be_instance_of(described_class)
      end

      it 'has no name or version' do
        expect(module_loader.name).to be_nil
        expect(module_loader.version).to be_nil
      end

      it 'returns a list of file loader objects' do
        expect(module_loader.files.map { |loader| loader.key }).to eq(test_data.map { |module_path, files| files.map { |name, _| "#{module_path}/SIMP/compliance_profiles/#{name}" } }.flatten)
      end
    end

    context 'with a metadata.json' do
      before(:each) do
        allow(File).to receive(:exist?).with("#{test_data.keys.first}/metadata.json").and_return(true)
        allow(File).to receive(:read).with("#{test_data.keys.first}/metadata.json").and_return('{"name": "author-test_module_00", "version": "2.0.0"}')
        allow(File).to receive(:size).with("#{test_data.keys.first}/metadata.json").and_return(53)
        allow(File).to receive(:mtime).with("#{test_data.keys.first}/metadata.json").and_return(Time.now)
      end

      it 'initializes' do
        expect(module_loader).not_to be_nil
        expect(module_loader).to be_instance_of(described_class)
      end

      it 'has a name' do
        expect(module_loader.name).to eq('author-test_module_00')
      end

      it 'has a version' do
        expect(module_loader.version).to eq('2.0.0')
      end

      it 'returns a list of file loader objects' do
        expect(module_loader.files.map { |loader| loader.key }).to eq(test_data.map { |module_path, files| files.map { |name, _| "#{module_path}/SIMP/compliance_profiles/#{name}" } }.flatten)
      end
    end
  end
end
