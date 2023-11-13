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

    allow(Dir).to receive(:exist?).and_call_original
    allow(Dir).to receive(:glob).and_call_original
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
        },
        'test_module_01' => {
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
      expect(compliance_engine.files).to eq(test_data.map { |module_path, files| files.map { |name, _| "#{module_path}/SIMP/compliance_profiles/#{name}" } }.flatten)
    end

    it 'returns a list of profiles' do
      expect(compliance_engine.profiles).to be_instance_of(ComplianceEngine::Profiles)
      expect(compliance_engine.profiles.keys).to eq(['test_profile_00', 'test_profile_01', 'test_profile_02'])
    end

    it 'returns a list of ces' do
      expect(compliance_engine.ces).to be_instance_of(ComplianceEngine::Ces)
      expect(compliance_engine.ces.keys).to eq(['ce_00', 'ce_01', 'ce_02', 'ce_03'])
    end
  end

  context 'with confines' do
    def test_data
      {
        'test_module_00' => {
          # Example from SCE docs
          'a/file.yaml' => <<~A_YAML,
            ---
            version: 2.0.0
            profiles:
              custom_profile_1:
                ces:
                  enable_widget_spinner_audit_logging: true
            ce:
              enable_widget_spinner_audit_logging:
                controls:
                  nist_800_53:rev4:AU-2: true
                title: 'Ensure logging is enabled for Widget Spinner'
                description: 'This setting enables usage and security logging for the Widget Spinner application.'
                confine:
                  os.release.major:
                    - 7
                    - 8
                  os.name:
                    - CentOS
                    - OracleLinux
                    - RedHat
            checks:
              widget_spinner_audit_logging:
                type: 'puppet-class-parameter'
                settings:
                  parameter: 'widget_spinner::audit_logging'
                  value: true
                ces:
                  - enable_widget_spinner_audit_logging
            A_YAML
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
      expect(compliance_engine.files).to eq(test_data.map { |module_path, files| files.map { |name, _| "#{module_path}/SIMP/compliance_profiles/#{name}" } }.flatten)
    end

    it 'returns a list of profiles' do
      expect(compliance_engine.profiles).to be_instance_of(ComplianceEngine::Profiles)
      expect(compliance_engine.profiles.keys).to eq(['custom_profile_1'])
    end

    it 'returns a list of ces' do
      expect(compliance_engine.ces).to be_instance_of(ComplianceEngine::Ces)
      expect(compliance_engine.ces.keys).to eq(['enable_widget_spinner_audit_logging'])
    end

    it 'returns a hash of confines' do
      expect(compliance_engine.confines).to be_instance_of(Hash)
      expect(compliance_engine.confines.keys).to eq(['os.release.major', 'os.name'])
    end
  end
end
