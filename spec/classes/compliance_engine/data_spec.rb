# frozen_string_literal: true

require 'spec_helper'
require 'compliance_engine'
require 'compliance_engine/data_loader'

RSpec.describe ComplianceEngine::Data do
  before(:each) do
    allow(File).to receive(:directory?).and_call_original
    allow(File).to receive(:file?).and_call_original
    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:mtime).and_call_original
    allow(File).to receive(:size).and_call_original

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
      expect { described_class.new('non_existant') }.to raise_error(ComplianceEngine::Error, %r{Invalid path or object})
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

  context 'with a ComplianceEngine::DataLoader object' do
    subject(:compliance_engine) { described_class.new(data_loader) }

    let(:data) do
      {
        'version' => '2.0.0',
      }
    end

    let(:data_loader) { ComplianceEngine::DataLoader.new(data) }

    it 'initializes' do
      expect(compliance_engine).not_to be_nil
      expect(compliance_engine).to be_instance_of(described_class)
    end

    it 'returns a UUID' do
      expect(compliance_engine.files.count).to eq(1)
      expect(compliance_engine.files.first).to match(%r{^Hash:[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$}i)
    end

    it 'get returns a hash' do
      expect(compliance_engine.get(compliance_engine.files.first)).to eq(data)
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
        allow(File).to receive(:directory?).with("#{module_path}/SIMP/compliance_profiles").and_return(true)
        allow(File).to receive(:directory?).with("#{module_path}/simp/compliance_profiles").and_return(false)
        allow(Dir).to receive(:glob).
          with("#{module_path}/SIMP/compliance_profiles/**/*.yaml").
          and_return(
            file_data.map { |name, _contents| "#{module_path}/SIMP/compliance_profiles/#{name}" }
          )
        allow(Dir).to receive(:glob).
          with("#{module_path}/SIMP/compliance_profiles/**/*.json").
          and_return([])

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
      expect(compliance_engine.profiles.keys).to eq(%w[test_profile_00 test_profile_01 test_profile_02])
    end

    it 'returns a list of ces' do
      expect(compliance_engine.ces).to be_instance_of(ComplianceEngine::Ces)
      expect(compliance_engine.ces.keys).to eq(%w[ce_00 ce_01 ce_02 ce_03])
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
                confine:
                  os.release.major:
                    - '7'
                    - '8'
                  os.name:
                    - CentOS
                    - OracleLinux
                    - RedHat
            ce:
              enable_widget_spinner_audit_logging:
                controls:
                  nist_800_53:rev4:AU-2: true
                title: 'Ensure logging is enabled for Widget Spinner'
                description: 'This setting enables usage and security logging for the Widget Spinner application.'
                confine:
                  os.release.major:
                    - '7'
                    - '8'
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
        allow(File).to receive(:directory?).with("#{module_path}/SIMP/compliance_profiles").and_return(true)
        allow(File).to receive(:directory?).with("#{module_path}/simp/compliance_profiles").and_return(false)
        allow(Dir).to receive(:glob).
          with("#{module_path}/SIMP/compliance_profiles/**/*.yaml").
          and_return(
            file_data.map { |name, _contents| "#{module_path}/SIMP/compliance_profiles/#{name}" }
          )
        allow(Dir).to receive(:glob).
          with("#{module_path}/SIMP/compliance_profiles/**/*.json").
          and_return([])

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
      profiles = compliance_engine.profiles
      expect(profiles).to be_instance_of(ComplianceEngine::Profiles)
      expect(profiles.keys).to eq(['custom_profile_1'])
    end

    it 'returns a list of ces' do
      ces = compliance_engine.ces
      expect(ces).to be_instance_of(ComplianceEngine::Ces)
      expect(ces.keys).to eq(['enable_widget_spinner_audit_logging'])
    end

    it 'returns a hash of confines' do
      confines = compliance_engine.confines
      expect(confines).to be_instance_of(Hash)
      expect(confines.keys).to eq(['os.release.major', 'os.name'])
    end

    it 'returns no hiera data when there are no profiles' do
      hiera = compliance_engine.hiera
      expect(hiera).to be_instance_of(Hash)
      expect(hiera).to eq({})
    end

    it 'returns no hiera data when there are no valid profiles' do
      hiera = compliance_engine.hiera(['invalid_profile'])
      expect(hiera).to be_instance_of(Hash)
      expect(hiera).to eq({})
    end

    it 'returns confined hiera data' do
      compliance_engine.facts = { 'os' => { 'release' => { 'major' => '7' }, 'name' => 'CentOS' } }
      hiera = compliance_engine.hiera(['custom_profile_1'])
      expect(hiera).to be_instance_of(Hash)
      expect(hiera).to eq({ 'widget_spinner::audit_logging' => true })
    end

    it 'skips hiera data when there is no match' do
      compliance_engine.facts = { 'os' => { 'release' => { 'major' => '12' }, 'name' => 'Debian' } }
      hiera = compliance_engine.hiera(['custom_profile_1'])
      expect(hiera).to be_instance_of(Hash)
      expect(hiera).to eq({})
    end

    it 'returns unconfined hiera data' do
      compliance_engine.facts = nil
      hiera = compliance_engine.hiera(['custom_profile_1'])
      expect(hiera).to be_instance_of(Hash)
      expect(hiera).to eq({ 'widget_spinner::audit_logging' => true })
    end
  end

  context 'with complex confines' do
    def test_data
      {
        'test_module_00' => {
          'a/file.yaml' => <<~A_YAML,
            ---
            version: 2.0.0
            profiles:
              custom_profile_1:
                ces:
                  enable_widget_spinner_audit_logging.el7: true
                confine:
                  os.release.major:
                    - '7'
                  os.name:
                    - CentOS
                    - OracleLinux
                    - RedHat
            ce:
              enable_widget_spinner_audit_logging.el7:
                controls:
                  nist_800_53:rev4:AU-2: true
                title: 'Ensure logging is enabled for Widget Spinner'
                description: 'This setting enables usage and security logging for the Widget Spinner application.'
                confine:
                  os.release.major:
                    - '7'
                  os.name:
                    - CentOS
                    - OracleLinux
                    - RedHat
            checks:
              widget_spinner_audit_logging_no:
                type: 'puppet-class-parameter'
                settings:
                  parameter: 'widget_spinner::audit_logging'
                  value: ['no']
                ces:
                  - enable_widget_spinner_audit_logging.el7
          A_YAML
          'b/file.yaml' => <<~B_YAML,
            ---
            version: 2.0.0
            profiles:
              custom_profile_1:
                ces:
                  enable_widget_spinner_audit_logging.el8: true
                confine:
                  os.release.major:
                    - '8'
                  os.name:
                    - CentOS
                    - OracleLinux
                    - RedHat
            ce:
              enable_widget_spinner_audit_logging.el8:
                controls:
                  nist_800_53:rev4:AU-2: true
                title: 'Ensure logging is enabled for Widget Spinner'
                description: 'This setting enables usage and security logging for the Widget Spinner application.'
                confine:
                  os.release.major:
                    - '8'
                  os.name:
                    - CentOS
                    - OracleLinux
                    - RedHat
            checks:
              widget_spinner_audit_logging_yes:
                type: 'puppet-class-parameter'
                settings:
                  parameter: 'widget_spinner::audit_logging'
                  value: ['yes']
                ces:
                  - enable_widget_spinner_audit_logging.el8
          B_YAML
          'c/file.yaml' => <<~C_YAML,
            ---
            version: 2.0.0
            profiles:
              custom_profile_1:
                ces:
                  enable_widget_spinner_audit_logging.el9: true
                confine:
                  os.release.major:
                    - '9'
                  os.name:
                    - CentOS
                    - OracleLinux
                    - RedHat
            ce:
              enable_widget_spinner_audit_logging.el9:
                controls:
                  nist_800_53:rev4:AU-2: true
                title: 'Ensure logging is enabled for Widget Spinner'
                description: 'This setting enables usage and security logging for the Widget Spinner application.'
                confine:
                  os.release.major:
                    - '9'
                  os.name:
                    - CentOS
                    - OracleLinux
                    - RedHat
            checks:
              widget_spinner_audit_logging_maybe:
                type: 'puppet-class-parameter'
                settings:
                  parameter: 'widget_spinner::audit_logging'
                  value: ['maybe']
                ces:
                  - enable_widget_spinner_audit_logging.el9
          C_YAML
        },
      }
    end

    subject(:compliance_engine) { described_class.new(*test_data.keys) }

    before(:each) do
      test_data.each do |module_path, file_data|
        allow(File).to receive(:directory?).with(module_path).and_return(true)
        allow(File).to receive(:directory?).with("#{module_path}/SIMP/compliance_profiles").and_return(true)
        allow(File).to receive(:directory?).with("#{module_path}/simp/compliance_profiles").and_return(false)
        allow(Dir).to receive(:glob).
          with("#{module_path}/SIMP/compliance_profiles/**/*.yaml").
          and_return(
            file_data.map { |name, _contents| "#{module_path}/SIMP/compliance_profiles/#{name}" }
          )
        allow(Dir).to receive(:glob).
          with("#{module_path}/SIMP/compliance_profiles/**/*.json").
          and_return([])

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
      profiles = compliance_engine.profiles
      expect(profiles).to be_instance_of(ComplianceEngine::Profiles)
      expect(profiles.keys).to eq(['custom_profile_1'])
    end

    it 'returns a list of ces' do
      ces = compliance_engine.ces
      expect(ces).to be_instance_of(ComplianceEngine::Ces)
      expect(ces.keys).to eq(['enable_widget_spinner_audit_logging.el7', 'enable_widget_spinner_audit_logging.el8', 'enable_widget_spinner_audit_logging.el9'])
    end

    it 'returns a hash of confines' do
      confines = compliance_engine.confines
      expect(confines).to be_instance_of(Hash)
      expect(confines.keys).to eq(['os.release.major', 'os.name'])
    end

    it 'returns no hiera data when there are no profiles' do
      hiera = compliance_engine.hiera
      expect(hiera).to be_instance_of(Hash)
      expect(hiera).to eq({})
    end

    it 'returns no hiera data when there are no valid profiles' do
      hiera = compliance_engine.hiera(['invalid_profile'])
      expect(hiera).to be_instance_of(Hash)
      expect(hiera).to eq({})
    end

    it 'returns confined hiera data' do
      compliance_engine.facts = { 'os' => { 'release' => { 'major' => '7' }, 'name' => 'CentOS' } }
      hiera = compliance_engine.hiera(['custom_profile_1'])
      expect(hiera).to be_instance_of(Hash)
      expect(hiera).to eq({ 'widget_spinner::audit_logging' => ['no'] })
    end

    it 'skips hiera data when there is no match' do
      compliance_engine.facts = { 'os' => { 'release' => { 'major' => '12' }, 'name' => 'Debian' } }
      hiera = compliance_engine.hiera(['custom_profile_1'])
      expect(hiera).to be_instance_of(Hash)
      expect(hiera).to eq({})
    end

    it 'returns unconfined hiera data' do
      compliance_engine.facts = nil
      hiera = compliance_engine.hiera(['custom_profile_1'])
      expect(hiera).to be_instance_of(Hash)
      expect(hiera).to eq({ 'widget_spinner::audit_logging' => %w[no yes maybe] })
    end

    it 'correctly invalidates cached data' do
      compliance_engine.facts = { 'os' => { 'release' => { 'major' => '7' }, 'name' => 'CentOS' } }
      hiera = compliance_engine.hiera(['custom_profile_1'])
      expect(hiera).to be_instance_of(Hash)
      expect(hiera).to eq({ 'widget_spinner::audit_logging' => ['no'] })

      compliance_engine.facts = { 'os' => { 'release' => { 'major' => '8' }, 'name' => 'RedHat' } }
      hiera = compliance_engine.hiera(['custom_profile_1'])
      expect(hiera).to be_instance_of(Hash)
      expect(hiera).to eq({ 'widget_spinner::audit_logging' => ['yes'] })

      compliance_engine.facts = nil
      hiera = compliance_engine.hiera(['custom_profile_1'])
      expect(hiera).to be_instance_of(Hash)
      expect(hiera).to eq({ 'widget_spinner::audit_logging' => %w[no yes maybe] })

      compliance_engine.facts = { 'os' => { 'release' => { 'major' => '9' }, 'name' => 'RedHat' } }
      hiera = compliance_engine.hiera(['custom_profile_1'])
      expect(hiera).to be_instance_of(Hash)
      expect(hiera).to eq({ 'widget_spinner::audit_logging' => ['maybe'] })
    end
  end

  context 'with mapping based on ce' do
    def test_data
      {
        'test_module_00' => {
          'a/file.yaml' => <<~A_YAML,
            ---
            version: 2.0.0
            profiles:
              custom_profile_1:
                ces:
                  enable_widget_spinner_audit_logging: true
                confine:
                  os.release.major:
                    - 7
                    - 8
                  os.name:
                    - CentOS
                    - OracleLinux
                    - RedHat
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
        allow(File).to receive(:directory?).with("#{module_path}/SIMP/compliance_profiles").and_return(true)
        allow(File).to receive(:directory?).with("#{module_path}/simp/compliance_profiles").and_return(false)
        allow(Dir).to receive(:glob).
          with("#{module_path}/SIMP/compliance_profiles/**/*.yaml").
          and_return(
            file_data.map { |name, _contents| "#{module_path}/SIMP/compliance_profiles/#{name}" }
          )
        allow(Dir).to receive(:glob).
          with("#{module_path}/SIMP/compliance_profiles/**/*.json").
          and_return([])

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
      profiles = compliance_engine.profiles
      expect(profiles).to be_instance_of(ComplianceEngine::Profiles)
      expect(profiles.keys).to eq(['custom_profile_1'])
    end

    it 'returns no hiera data when there are no profiles' do
      hiera = compliance_engine.hiera
      expect(hiera).to be_instance_of(Hash)
      expect(hiera).to eq({})
    end

    it 'returns no hiera data when there are no valid profiles' do
      hiera = compliance_engine.hiera(['invalid_profile'])
      expect(hiera).to be_instance_of(Hash)
      expect(hiera).to eq({})
    end

    it 'returns hiera data' do
      hiera = compliance_engine.hiera(['custom_profile_1'])
      expect(hiera).to be_instance_of(Hash)
      expect(hiera).to eq({ 'widget_spinner::audit_logging' => true })
    end

    it 'returns checks for a profile' do
      checks = compliance_engine.check_mapping(compliance_engine.profiles['custom_profile_1'])
      checks.each_value { |check| expect(check).to be_instance_of(ComplianceEngine::Check) }
      keys = checks.values.map(&:key)
      expect(keys).to be_instance_of(Array)
      expect(keys).to eq(['widget_spinner_audit_logging'])
    end

    it 'returns checks for a ce' do
      checks = compliance_engine.check_mapping(compliance_engine.ces['enable_widget_spinner_audit_logging'])
      checks.each_value { |check| expect(check).to be_instance_of(ComplianceEngine::Check) }
      keys = checks.values.map(&:key)
      expect(keys).to be_instance_of(Array)
      expect(keys).to eq(['widget_spinner_audit_logging'])
    end
  end

  context 'with mapping based on control' do
    def test_data
      {
        'test_module_00' => {
          'a/file.yaml' => <<~A_YAML,
            ---
            version: 2.0.0
            profiles:
              custom_profile_1:
                controls:
                  nist_800_53:rev4:AU-2: true
            checks:
              widget_spinner_audit_logging:
                type: 'puppet-class-parameter'
                settings:
                  parameter: 'widget_spinner::audit_logging'
                  value: true
                controls:
                  nist_800_53:rev4:AU-2: true
          A_YAML
        },
      }
    end

    subject(:compliance_engine) { described_class.new(*test_data.keys) }

    before(:each) do
      test_data.each do |module_path, file_data|
        allow(File).to receive(:directory?).with(module_path).and_return(true)
        allow(File).to receive(:directory?).with("#{module_path}/SIMP/compliance_profiles").and_return(true)
        allow(File).to receive(:directory?).with("#{module_path}/simp/compliance_profiles").and_return(false)
        allow(Dir).to receive(:glob).
          with("#{module_path}/SIMP/compliance_profiles/**/*.yaml").
          and_return(
            file_data.map { |name, _contents| "#{module_path}/SIMP/compliance_profiles/#{name}" }
          )
        allow(Dir).to receive(:glob).
          with("#{module_path}/SIMP/compliance_profiles/**/*.json").
          and_return([])

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
      profiles = compliance_engine.profiles
      expect(profiles).to be_instance_of(ComplianceEngine::Profiles)
      expect(profiles.keys).to eq(['custom_profile_1'])
    end

    it 'returns no hiera data when there are no profiles' do
      hiera = compliance_engine.hiera
      expect(hiera).to be_instance_of(Hash)
      expect(hiera).to eq({})
    end

    it 'returns no hiera data when there are no valid profiles' do
      hiera = compliance_engine.hiera(['invalid_profile'])
      expect(hiera).to be_instance_of(Hash)
      expect(hiera).to eq({})
    end

    it 'returns hiera data' do
      hiera = compliance_engine.hiera(['custom_profile_1'])
      expect(hiera).to be_instance_of(Hash)
      expect(hiera).to eq({ 'widget_spinner::audit_logging' => true })
    end
  end

  context 'with direct mapping to checks' do
    def test_data
      {
        'test_module_00' => {
          'a/file.yaml' => <<~A_YAML,
            ---
            version: 2.0.0
            profiles:
              00_profile_with_check_reference:
                checks:
                  00_check: true
            checks:
              00_check:
                type: puppet-class-parameter
                settings:
                  parameter: test_module_00::test_param
                  value: a string
          A_YAML
        },
      }
    end

    subject(:compliance_engine) { described_class.new(*test_data.keys) }

    before(:each) do
      test_data.each do |module_path, file_data|
        allow(File).to receive(:directory?).with(module_path).and_return(true)
        allow(File).to receive(:directory?).with("#{module_path}/SIMP/compliance_profiles").and_return(true)
        allow(File).to receive(:directory?).with("#{module_path}/simp/compliance_profiles").and_return(false)
        allow(Dir).to receive(:glob).
          with("#{module_path}/SIMP/compliance_profiles/**/*.yaml").
          and_return(
            file_data.map { |name, _contents| "#{module_path}/SIMP/compliance_profiles/#{name}" }
          )
        allow(Dir).to receive(:glob).
          with("#{module_path}/SIMP/compliance_profiles/**/*.json").
          and_return([])

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
      profiles = compliance_engine.profiles
      expect(profiles).to be_instance_of(ComplianceEngine::Profiles)
      expect(profiles.keys).to eq(['00_profile_with_check_reference'])
    end

    it 'returns no hiera data when there are no profiles' do
      hiera = compliance_engine.hiera
      expect(hiera).to be_instance_of(Hash)
      expect(hiera).to eq({})
    end

    it 'returns no hiera data when there are no valid profiles' do
      hiera = compliance_engine.hiera(['invalid_profile'])
      expect(hiera).to be_instance_of(Hash)
      expect(hiera).to eq({})
    end

    it 'returns hiera data' do
      hiera = compliance_engine.hiera(['00_profile_with_check_reference'])
      expect(hiera).to be_instance_of(Hash)
      expect(hiera).to eq({ 'test_module_00::test_param' => 'a string' })
    end
  end

  context 'with mapping based on ce + control' do
    def test_data
      {
        'test_module_00' => {
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
            checks:
              widget_spinner_audit_logging:
                type: 'puppet-class-parameter'
                settings:
                  parameter: 'widget_spinner::audit_logging'
                  value: true
                controls:
                  nist_800_53:rev4:AU-2: true
          A_YAML
          'b/file.yaml' => <<~B_YAML,
            ---
            version: 2.0.0
            profiles:
              00_profile_test:
                controls:
                  00_control1: true
            ce:
              00_ce1:
                controls:
                  00_control1: true
            checks:
              00_check1:
                type: 'puppet-class-parameter'
                settings:
                  parameter: 'test_module_00::test_param'
                  value: 'a string'
                ces:
                  - 00_ce1
          B_YAML
        },
      }
    end

    subject(:compliance_engine) { described_class.new(*test_data.keys) }

    before(:each) do
      test_data.each do |module_path, file_data|
        allow(File).to receive(:directory?).with(module_path).and_return(true)
        allow(File).to receive(:directory?).with("#{module_path}/SIMP/compliance_profiles").and_return(true)
        allow(File).to receive(:directory?).with("#{module_path}/simp/compliance_profiles").and_return(false)
        allow(Dir).to receive(:glob).
          with("#{module_path}/SIMP/compliance_profiles/**/*.yaml").
          and_return(
            file_data.map { |name, _contents| "#{module_path}/SIMP/compliance_profiles/#{name}" }
          )
        allow(Dir).to receive(:glob).
          with("#{module_path}/SIMP/compliance_profiles/**/*.json").
          and_return([])

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
      profiles = compliance_engine.profiles
      expect(profiles).to be_instance_of(ComplianceEngine::Profiles)
      expect(profiles.keys).to eq(%w[custom_profile_1 00_profile_test])
    end

    it 'returns a list of ces' do
      ces = compliance_engine.ces
      expect(ces).to be_instance_of(ComplianceEngine::Ces)
      expect(ces.keys).to eq(%w[enable_widget_spinner_audit_logging 00_ce1])
    end

    it 'returns no hiera data when there are no profiles' do
      hiera = compliance_engine.hiera
      expect(hiera).to be_instance_of(Hash)
      expect(hiera).to eq({})
    end

    it 'returns no hiera data when there are no valid profiles' do
      hiera = compliance_engine.hiera(['invalid_profile'])
      expect(hiera).to be_instance_of(Hash)
      expect(hiera).to eq({})
    end

    it 'returns hiera data for custom_profile_1' do
      hiera = compliance_engine.hiera(['custom_profile_1'])
      expect(hiera).to be_instance_of(Hash)
      expect(hiera).to eq({ 'widget_spinner::audit_logging' => true })
    end

    it 'returns hiera data for 00_profile_test' do
      hiera = compliance_engine.hiera(['00_profile_test'])
      expect(hiera).to be_instance_of(Hash)
      expect(hiera).to eq({ 'test_module_00::test_param' => 'a string' })
    end

    it 'returns checks for custom_profile_1' do
      checks = compliance_engine.check_mapping(compliance_engine.profiles['custom_profile_1'])
      checks.each_value { |check| expect(check).to be_instance_of(ComplianceEngine::Check) }
      keys = checks.values.map(&:key)
      expect(keys).to be_instance_of(Array)
      expect(keys).to eq(['widget_spinner_audit_logging'])
    end

    it 'returns checks for 00_profile_test' do
      checks = compliance_engine.check_mapping(compliance_engine.profiles['00_profile_test'])
      checks.each_value { |check| expect(check).to be_instance_of(ComplianceEngine::Check) }
      keys = checks.values.map(&:key)
      expect(keys).to be_instance_of(Array)
      expect(keys).to eq(['00_check1'])
    end

    it 'returns checks for enable_widget_spinner_audit_logging' do
      checks = compliance_engine.check_mapping(compliance_engine.ces['enable_widget_spinner_audit_logging'])
      checks.each_value { |check| expect(check).to be_instance_of(ComplianceEngine::Check) }
      keys = checks.values.map(&:key)
      expect(keys).to be_instance_of(Array)
      expect(keys).to eq(['widget_spinner_audit_logging'])
    end

    it 'returns checks for 00_ce1' do
      checks = compliance_engine.check_mapping(compliance_engine.ces['00_ce1'])
      checks.each_value { |check| expect(check).to be_instance_of(ComplianceEngine::Check) }
      keys = checks.values.map(&:key)
      expect(keys).to be_instance_of(Array)
      expect(keys).to eq(['00_check1'])
    end
  end

  context 'with zip data' do
    subject(:compliance_engine) { described_class.new }

    let(:test_data) { File.expand_path('../../fixtures/test_environment.zip', __dir__) }
    let(:test_files) do
      [
        'test_module_00/SIMP/compliance_profiles/a/file.yaml',
        'test_module_00/SIMP/compliance_profiles/b/file.yaml',
        'test_module_01/SIMP/compliance_profiles/c/file.yaml',
      ]
    end

    before(:each) do
      compliance_engine.open_environment_zip(test_data)
    end

    it 'initializes' do
      expect(compliance_engine).not_to be_nil
      expect(compliance_engine).to be_instance_of(described_class)
    end

    it 'returns the modulepath' do
      expect(compliance_engine.modulepath).to eq(test_data)
    end

    it 'returns a list of files' do
      expect(compliance_engine.files).to eq(test_files.map { |file| File.join(test_data, '.', file) })
    end

    it 'returns a list of profiles' do
      expect(compliance_engine.profiles).to be_instance_of(ComplianceEngine::Profiles)
      expect(compliance_engine.profiles.keys).to eq(%w[test_profile_00 test_profile_01 test_profile_02])
    end

    it 'returns a list of ces' do
      expect(compliance_engine.ces).to be_instance_of(ComplianceEngine::Ces)
      expect(compliance_engine.ces.keys).to eq(%w[ce_00 ce_01 ce_02 ce_03])
    end
  end

  context 'with a supplied module path' do
    subject(:compliance_engine) { described_class.new }

    let(:test_data) { File.expand_path('../../fixtures', __dir__) }
    let(:test_files) do
      [
        'test_module_00/SIMP/compliance_profiles/a/file.yaml',
        'test_module_00/SIMP/compliance_profiles/b/file.yaml',
        'test_module_01/SIMP/compliance_profiles/c/file.yaml',
      ]
    end

    before(:each) do
      compliance_engine.open_environment(test_data)
    end

    it 'initializes' do
      expect(compliance_engine).not_to be_nil
      expect(compliance_engine).to be_instance_of(described_class)
    end

    it 'returns the modulepath' do
      expect(compliance_engine.modulepath).to eq([test_data])
    end

    it 'returns a list of files' do
      expect(compliance_engine.files).to eq(test_files.map { |file| File.join(test_data, file) })
    end

    it 'returns a list of profiles' do
      expect(compliance_engine.profiles).to be_instance_of(ComplianceEngine::Profiles)
      expect(compliance_engine.profiles.keys).to eq(%w[test_profile_00 test_profile_01 test_profile_02])
    end

    it 'returns a list of ces' do
      expect(compliance_engine.ces).to be_instance_of(ComplianceEngine::Ces)
      expect(compliance_engine.ces.keys).to eq(%w[ce_00 ce_01 ce_02 ce_03])
    end
  end
end
