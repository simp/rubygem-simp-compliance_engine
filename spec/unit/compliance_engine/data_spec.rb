# frozen_string_literal: true

require 'spec_helper'
require 'compliance_engine'

RSpec.describe ComplianceEngine::Data do
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

  context 'with a json file path' do
    subject(:compliance_engine) { described_class.new('file.json') }

    before(:each) do
      allow(File).to receive(:directory?).with('file.json').and_return(false)
      allow(File).to receive(:file?).with('file.json').and_return(true)
      allow(File).to receive(:size).with('file.json').and_return(18)
      allow(File).to receive(:mtime).with('file.json').and_return(Time.now)
      allow(File).to receive(:read).with('file.json').and_return('{"version": "2.0.0"}')
    end

    it 'initializes' do
      expect(compliance_engine).not_to be_nil
      expect(compliance_engine).to be_instance_of(described_class)
    end

    it 'returns a list of files' do
      expect(compliance_engine.files).to eq(['file.json'])
    end

    it 'get returns a hash' do
      expect(compliance_engine.get('file.json')).to eq({ 'version' => '2.0.0' })
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

  context 'with an invalid version number' do
    subject(:compliance_engine) { described_class.new('file') }

    before(:each) do
      allow(File).to receive(:directory?).with('file').and_return(false)
      allow(File).to receive(:file?).with('file').and_return(true)
      allow(File).to receive(:size).with('file').and_return(0)
      allow(File).to receive(:mtime).with('file').and_return(Time.now)
      allow(File).to receive(:read).with('file').and_return("---\nversion: 1.0")
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

  context 'with complex data' do
    def test_data
      {
        'test_module_00' => {
          'a/file.yaml' => <<~A_YAML,
            version: '2.0.0'
            profiles:
              test_profile_00:
                ces:
                  ce_00: true
              test_profile_01:
                ces:
                  ce_01: true
            A_YAML
          'b/file.yaml' => <<~B_YAML,
            version: '2.0.0'
            profiles:
              test_profile_01:
                ces:
                  ce_02: true
            B_YAML
        },
      }
    end

    subject(:compliance_engine) { described_class.new(*test_data.keys) }

    before(:each) do
      test_data.each do |module_path, file_data|
        allow(File).to receive(:directory?).with(module_path).and_return(true)
        allow(Dir).to receive(:exist?).with("#{module_path}/SIMP/compliance_profiles").and_return(true)
        allow(Dir).to receive(:exist?).with("#{module_path}/simp/compliance_profiles").and_return(false)
        allow(Dir).to receive(:glob).with(
          [
            "#{module_path}/SIMP/compliance_profiles/**/*.yaml",
            "#{module_path}/SIMP/compliance_profiles/**/*.json",
          ],
        ).and_return(
          file_data.map { |name, _contents| "#{module_path}/SIMP/compliance_profiles/#{name}" },
        )

        file_data.each do |name, contents|
          filename = "#{module_path}/SIMP/compliance_profiles/#{name}"
          allow(File).to receive(:size).with(filename).and_return(contents.length)
          allow(File).to receive(:mtime).with(filename).and_return(Time.now)
          allow(File).to receive(:read).with(filename).and_return(contents)
        end
      end
    end

    it 'initializes' do
      expect(compliance_engine).not_to be_nil
      expect(compliance_engine).to be_instance_of(described_class)
    end

    it 'returns a list of files' do
      expect(compliance_engine.files).to eq(test_data.map { |module_path, files| files.map { |name, content| "#{module_path}/SIMP/compliance_profiles/#{name}" } }.flatten)
    end

    it 'returns a list of profiles' do
      expect(compliance_engine.profiles).to be_instance_of(ComplianceEngine::Data::Profiles)
      expect(compliance_engine.profiles.keys).to eq(['test_profile_00', 'test_profile_01'])
    end
  end
end
