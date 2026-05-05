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
      allow(ComplianceEngine.log).to receive(:error)
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

    it 'logs an error' do
      compliance_engine.files
      expect(ComplianceEngine.log).to have_received(:error).with('Data must be a hash')
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
      allow(ComplianceEngine.log).to receive(:error)
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

    it 'logs an error' do
      compliance_engine.files
      expect(ComplianceEngine.log).to have_received(:error).with("Unsupported version '1.0'")
    end
  end

  context 'with a missing version key' do
    subject(:compliance_engine) { described_class.new('file') }

    before(:each) do
      allow(File).to receive(:directory?).with('file').and_return(false)
      allow(File).to receive(:file?).with('file').and_return(true)
      allow(File).to receive(:size).with('file').and_return(0)
      allow(File).to receive(:mtime).with('file').and_return(Time.now)
      allow(File).to receive(:read).with('file').and_return("---\nprofiles: {}")
      allow(ComplianceEngine.log).to receive(:error)
    end

    it 'initializes without raising' do
      expect { compliance_engine }.not_to raise_error
    end

    it 'returns an empty list of files' do
      expect(compliance_engine.files).to eq([])
    end

    it 'logs an error' do
      compliance_engine.files
      expect(ComplianceEngine.log).to have_received(:error).with('Missing version')
    end
  end

  context 'with malformed YAML content' do
    subject(:compliance_engine) { described_class.new('file') }

    before(:each) do
      allow(File).to receive(:directory?).with('file').and_return(false)
      allow(File).to receive(:file?).with('file').and_return(true)
      allow(File).to receive(:size).with('file').and_return(0)
      allow(File).to receive(:mtime).with('file').and_return(Time.now)
      allow(File).to receive(:read).with('file').and_return("---\nkey: {unclosed")
      allow(ComplianceEngine.log).to receive(:error)
    end

    it 'initializes without raising' do
      expect { compliance_engine }.not_to raise_error
    end

    it 'returns an empty list of files' do
      expect(compliance_engine.files).to eq([])
    end

    it 'logs an error' do
      compliance_engine.files
      expect(ComplianceEngine.log).to have_received(:error)
    end
  end

  context 'with a non-hash collection value in data' do
    subject(:compliance_engine) { described_class.new('file') }

    before(:each) do
      allow(File).to receive(:directory?).with('file').and_return(false)
      allow(File).to receive(:file?).with('file').and_return(true)
      allow(File).to receive(:size).with('file').and_return(0)
      allow(File).to receive(:mtime).with('file').and_return(Time.now)
      allow(File).to receive(:read).with('file').and_return(
        "---\nversion: '2.0.0'\nprofiles: not_a_hash\n",
      )
      allow(ComplianceEngine.log).to receive(:error)
    end

    it 'initializes without raising' do
      expect { compliance_engine }.not_to raise_error
    end

    it 'returns the file as loaded' do
      expect(compliance_engine.files).to eq(['file'])
    end

    it 'returns an empty profiles collection' do
      expect(compliance_engine.profiles.keys).to eq([])
    end

    it 'logs an error for the invalid profiles value' do
      compliance_engine.profiles
      expect(ComplianceEngine.log).to have_received(:error).with(%r{Expected 'profiles' in file to be a Hash})
    end
  end

  context 'with one valid file and one malformed file' do
    subject(:compliance_engine) { described_class.new('good_file', 'bad_file') }

    let(:good_content) do
      <<~YAML
        ---
        version: '2.0.0'
        profiles:
          valid_profile:
            ces:
              valid_ce: true
        ce:
          valid_ce: {}
        checks:
          valid_check:
            type: puppet-class-parameter
            settings:
              parameter: mymodule::param
              value: valid_value
            ces:
              - valid_ce
      YAML
    end

    before(:each) do
      allow(File).to receive(:directory?).with('good_file').and_return(false)
      allow(File).to receive(:file?).with('good_file').and_return(true)
      allow(File).to receive(:size).with('good_file').and_return(good_content.length)
      allow(File).to receive(:mtime).with('good_file').and_return(Time.now)
      allow(File).to receive(:read).with('good_file').and_return(good_content)

      allow(File).to receive(:directory?).with('bad_file').and_return(false)
      allow(File).to receive(:file?).with('bad_file').and_return(true)
      allow(File).to receive(:size).with('bad_file').and_return(0)
      allow(File).to receive(:mtime).with('bad_file').and_return(Time.now)
      allow(File).to receive(:read).with('bad_file').and_return("---\nversion: 1.0")

      allow(ComplianceEngine.log).to receive(:error)
    end

    it 'initializes without raising' do
      expect { compliance_engine }.not_to raise_error
    end

    it 'loads the valid file and skips the malformed file' do
      expect(compliance_engine.files).to eq(['good_file'])
    end

    it 'logs an error for the malformed file' do
      compliance_engine.files
      expect(ComplianceEngine.log).to have_received(:error).with("Unsupported version '1.0'")
    end

    it 'returns hiera data from the valid file' do
      expect(compliance_engine.hiera(['valid_profile'])).to include('mymodule::param' => 'valid_value')
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
      expect(hiera).to eq({ 'widget_spinner::audit_logging' => ['no', 'yes', 'maybe'] })
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
      expect(hiera).to eq({ 'widget_spinner::audit_logging' => ['no', 'yes', 'maybe'] })

      compliance_engine.facts = { 'os' => { 'release' => { 'major' => '9' }, 'name' => 'RedHat' } }
      hiera = compliance_engine.hiera(['custom_profile_1'])
      expect(hiera).to be_instance_of(Hash)
      expect(hiera).to eq({ 'widget_spinner::audit_logging' => ['maybe'] })
    end
  end

  context 'with scalar confine values across multiple components' do
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
                  os.name: CentOS
            ce:
              enable_widget_spinner_audit_logging:
                controls:
                  nist_800_53:rev4:AU-2: true
                confine:
                  os.name: CentOS
            checks:
              widget_spinner_audit_logging:
                type: 'puppet-class-parameter'
                settings:
                  parameter: 'widget_spinner::audit_logging'
                  value: true
                ces:
                  - enable_widget_spinner_audit_logging
          A_YAML
          'b/file.yaml' => <<~B_YAML,
            ---
            version: 2.0.0
            profiles:
              custom_profile_2:
                ces:
                  enable_widget_spinner_audit_logging: true
                confine:
                  os.name: RedHat
            ce:
              enable_widget_spinner_audit_logging:
                controls:
                  nist_800_53:rev4:AU-2: true
                confine:
                  os.name: RedHat
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

    it 'merges scalar confine values into arrays without error' do
      confines = compliance_engine.confines
      expect(confines).to be_instance_of(Hash)
      expect(confines['os.name']).to be_instance_of(Array)
      expect(confines['os.name']).to include('CentOS', 'RedHat')
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
      expect(profiles.keys).to eq(['custom_profile_1', '00_profile_test'])
    end

    it 'returns a list of ces' do
      ces = compliance_engine.ces
      expect(ces).to be_instance_of(ComplianceEngine::Ces)
      expect(ces.keys).to eq(['enable_widget_spinner_audit_logging', '00_ce1'])
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

  context 'with explicit `false` exclusions in profile mappings' do
    def test_data
      {
        'test_module_00' => {
          'a/file.yaml' => <<~A_YAML,
            ---
            version: 2.0.0
            profiles:
              profile_with_excluded_ce:
                controls:
                  XY-n: true
                ces:
                  abc: false
              profile_with_excluded_check:
                controls:
                  XY-n: true
                checks:
                  excluded_check: false
              profile_with_partial_ce_exclusion:
                controls:
                  XY-n: true
                ces:
                  xyz: false
              profile_baseline:
                controls:
                  XY-n: true
            ce:
              abc:
                controls:
                  XY-n: true
              xyz:
                controls:
                  XY-n: true
              other_ce:
                controls:
                  XY-n: true
            checks:
              check_via_excluded_ce:
                type: 'puppet-class-parameter'
                settings:
                  parameter: 'test_module_00::via_excluded_ce'
                  value: 'should be excluded'
                ces:
                  - abc
              check_via_other_ce:
                type: 'puppet-class-parameter'
                settings:
                  parameter: 'test_module_00::via_other_ce'
                  value: 'should be included'
                ces:
                  - other_ce
              check_via_two_ces:
                type: 'puppet-class-parameter'
                settings:
                  parameter: 'test_module_00::via_two_ces'
                  value: 'should be included via abc'
                ces:
                  - abc
                  - xyz
              excluded_check:
                type: 'puppet-class-parameter'
                settings:
                  parameter: 'test_module_00::hard_excluded'
                  value: 'should never appear'
                controls:
                  XY-n: true
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

    it 'excludes a CE explicitly set to false even when the CE matches a positive control' do
      checks = compliance_engine.check_mapping(compliance_engine.profiles['profile_with_excluded_ce'])
      keys = checks.values.map(&:key)
      expect(keys).not_to include('check_via_excluded_ce')
      expect(keys).to include('check_via_other_ce')
    end

    it 'omits hiera data for checks reachable only via an excluded CE' do
      hiera = compliance_engine.hiera(['profile_with_excluded_ce'])
      expect(hiera).not_to have_key('test_module_00::via_excluded_ce')
      expect(hiera).to include('test_module_00::via_other_ce' => 'should be included')
    end

    it 'still includes a check that has another non-excluded CE as a bridge' do
      checks = compliance_engine.check_mapping(compliance_engine.profiles['profile_with_partial_ce_exclusion'])
      keys = checks.values.map(&:key)
      expect(keys).to include('check_via_two_ces')
    end

    it 'hard-excludes a check explicitly set to false even when other routes match' do
      checks = compliance_engine.check_mapping(compliance_engine.profiles['profile_with_excluded_check'])
      keys = checks.values.map(&:key)
      expect(keys).not_to include('excluded_check')
    end

    it 'omits hiera data for a hard-excluded check' do
      hiera = compliance_engine.hiera(['profile_with_excluded_check'])
      expect(hiera).not_to have_key('test_module_00::hard_excluded')
    end

    it 'still includes unrelated checks when a different CE is excluded (regression guard)' do
      excluded_keys = compliance_engine.check_mapping(compliance_engine.profiles['profile_with_excluded_ce']).values.map(&:key)
      baseline_keys = compliance_engine.check_mapping(compliance_engine.profiles['profile_baseline']).values.map(&:key)
      expect(excluded_keys).to include('check_via_other_ce')
      expect(baseline_keys).to include('check_via_other_ce')
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
      expect(compliance_engine.profiles.keys).to eq(['test_profile_00', 'test_profile_01', 'test_profile_02'])
    end

    it 'returns a list of ces' do
      expect(compliance_engine.ces).to be_instance_of(ComplianceEngine::Ces)
      expect(compliance_engine.ces.keys).to eq(['ce_00', 'ce_01', 'ce_02', 'ce_03'])
    end
  end

  context 'with zip_bytes data' do
    subject(:compliance_engine) { described_class.new }

    let(:zip_path) { File.expand_path('../../fixtures/test_environment.zip', __dir__) }
    let(:bytes) { File.binread(zip_path) }
    let(:test_files) do
      [
        'test_module_00/SIMP/compliance_profiles/a/file.yaml',
        'test_module_00/SIMP/compliance_profiles/b/file.yaml',
        'test_module_01/SIMP/compliance_profiles/c/file.yaml',
      ]
    end

    before(:each) do
      compliance_engine.open_environment_zip_bytes(bytes)
    end

    it 'initializes' do
      expect(compliance_engine).not_to be_nil
      expect(compliance_engine).to be_instance_of(described_class)
    end

    it 'defaults modulepath to "-"' do
      expect(compliance_engine.modulepath).to eq('-')
    end

    it 'returns a list of files' do
      expect(compliance_engine.files).to eq(test_files.map { |file| File.join('-', '.', file) })
    end

    it 'returns a list of profiles' do
      expect(compliance_engine.profiles).to be_instance_of(ComplianceEngine::Profiles)
      expect(compliance_engine.profiles.keys).to eq(['test_profile_00', 'test_profile_01', 'test_profile_02'])
    end

    it 'returns a list of ces' do
      expect(compliance_engine.ces).to be_instance_of(ComplianceEngine::Ces)
      expect(compliance_engine.ces.keys).to eq(['ce_00', 'ce_01', 'ce_02', 'ce_03'])
    end

    it 'uses an explicit name as modulepath' do
      engine = described_class.new
      engine.open_environment_zip_bytes(bytes, name: 'buffer.zip')
      expect(engine.modulepath).to eq('buffer.zip')
      expect(engine.ces.keys).to eq(['ce_00', 'ce_01', 'ce_02', 'ce_03'])
    end
  end

  # Regression lock: open_environment_zip previously accepted a pre-opened
  # Zip::File, which allowed consumers to trigger a silent empty-load bug when
  # the Zip::File was opened before zip/filesystem was required.  Ensure that
  # path is permanently closed.
  context 'regression: zip/filesystem require-order bug' do
    let(:zip_path) { File.expand_path('../../fixtures/test_environment.zip', __dir__) }
    let(:bytes) { File.binread(zip_path) }

    it 'open_environment_zip rejects a pre-opened Zip::File' do
      require 'zip'
      Zip::File.open_buffer(bytes) do |zip|
        expect { described_class.new.open_environment_zip(zip) }.to raise_error(ArgumentError, %r{must be a String path})
      end
    end
  end

  context 'with multiple profiles and conflicting settings' do
    subject(:compliance_engine) { described_class.new(module_path) }

    let(:profile_a_yaml) do
      <<~YAML
        ---
        version: 2.0.0
        profiles:
          profile_a:
            ces:
              ce_a: true
        ce:
          ce_a:
            controls:
              control_a: true
        checks:
          check_string_a:
            type: puppet-class-parameter
            settings:
              parameter: mymodule::string_param
              value: value from A
            ces:
              - ce_a
          check_array_a:
            type: puppet-class-parameter
            settings:
              parameter: mymodule::array_param
              value:
                - a1
                - a2
            ces:
              - ce_a
          check_hash_a:
            type: puppet-class-parameter
            settings:
              parameter: mymodule::hash_param
              value:
                shared_key: from A
                a_only_key: a value
            ces:
              - ce_a
      YAML
    end

    let(:profile_b_yaml) do
      <<~YAML
        ---
        version: 2.0.0
        profiles:
          profile_b:
            ces:
              ce_b: true
        ce:
          ce_b:
            controls:
              control_b: true
        checks:
          check_string_b:
            type: puppet-class-parameter
            settings:
              parameter: mymodule::string_param
              value: value from B
            ces:
              - ce_b
          check_array_b:
            type: puppet-class-parameter
            settings:
              parameter: mymodule::array_param
              value:
                - b1
                - b2
            ces:
              - ce_b
          check_hash_b:
            type: puppet-class-parameter
            settings:
              parameter: mymodule::hash_param
              value:
                shared_key: from B
                b_only_key: b value
            ces:
              - ce_b
      YAML
    end

    let(:module_path) { 'test_merge_module' }

    before(:each) do
      allow(File).to receive(:directory?).with(module_path).and_return(true)
      allow(File).to receive(:directory?).with("#{module_path}/SIMP/compliance_profiles").and_return(true)
      allow(File).to receive(:directory?).with("#{module_path}/simp/compliance_profiles").and_return(false)
      allow(Dir).to receive(:glob)
        .with("#{module_path}/SIMP/compliance_profiles/**/*.yaml")
        .and_return([
                      "#{module_path}/SIMP/compliance_profiles/profile_a.yaml",
                      "#{module_path}/SIMP/compliance_profiles/profile_b.yaml",
                    ])
      allow(Dir).to receive(:glob)
        .with("#{module_path}/SIMP/compliance_profiles/**/*.json")
        .and_return([])

      [['profile_a.yaml', profile_a_yaml], ['profile_b.yaml', profile_b_yaml]].each do |name, contents|
        filename = "#{module_path}/SIMP/compliance_profiles/#{name}"
        allow(File).to receive(:size).with(filename).and_return(contents.length)
        allow(File).to receive(:mtime).with(filename).and_return(Time.now)
        allow(File).to receive(:read).with(filename).and_return(contents)
      end
    end

    context 'when profile_a is listed before profile_b' do
      let(:hiera) { compliance_engine.hiera(['profile_a', 'profile_b']) }

      it 'profile_a wins for string parameters' do
        expect(hiera['mymodule::string_param']).to eq('value from A')
      end

      it 'merges array parameters with profile_a values appended last (highest priority)' do
        expect(hiera['mymodule::array_param']).to eq(['b1', 'b2', 'a1', 'a2'])
      end

      it 'deep-merges hash parameters with profile_a winning on shared keys' do
        expect(hiera['mymodule::hash_param']).to include(
          'shared_key' => 'from A',
          'a_only_key' => 'a value',
          'b_only_key' => 'b value',
        )
      end
    end

    context 'when profile_b is listed before profile_a' do
      let(:hiera) { compliance_engine.hiera(['profile_b', 'profile_a']) }

      it 'profile_b wins for string parameters' do
        expect(hiera['mymodule::string_param']).to eq('value from B')
      end

      it 'merges array parameters with profile_b values appended last (highest priority)' do
        expect(hiera['mymodule::array_param']).to eq(['a1', 'a2', 'b1', 'b2'])
      end

      it 'deep-merges hash parameters with profile_b winning on shared keys' do
        expect(hiera['mymodule::hash_param']).to include(
          'shared_key' => 'from B',
          'a_only_key' => 'a value',
          'b_only_key' => 'b value',
        )
      end
    end

    context 'when only profile_a is requested' do
      let(:hiera) { compliance_engine.hiera(['profile_a']) }

      it 'returns only profile_a settings' do
        expect(hiera['mymodule::string_param']).to eq('value from A')
        expect(hiera['mymodule::array_param']).to eq(['a1', 'a2'])
        expect(hiera['mymodule::hash_param']).to include('shared_key' => 'from A', 'a_only_key' => 'a value')
        expect(hiera['mymodule::hash_param']).not_to have_key('b_only_key')
      end
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
      expect(compliance_engine.profiles.keys).to eq(['test_profile_00', 'test_profile_01', 'test_profile_02'])
    end

    it 'returns a list of ces' do
      expect(compliance_engine.ces).to be_instance_of(ComplianceEngine::Ces)
      expect(compliance_engine.ces.keys).to eq(['ce_00', 'ce_01', 'ce_02', 'ce_03'])
    end
  end

  context 'with knockout_prefix support' do
    def setup_module(module_path, file_data)
      allow(File).to receive(:directory?).with(module_path).and_return(true)
      allow(File).to receive(:directory?).with("#{module_path}/SIMP/compliance_profiles").and_return(true)
      allow(File).to receive(:directory?).with("#{module_path}/simp/compliance_profiles").and_return(false)
      allow(Dir).to receive(:glob)
        .with("#{module_path}/SIMP/compliance_profiles/**/*.yaml")
        .and_return(file_data.map { |name, _| "#{module_path}/SIMP/compliance_profiles/#{name}" })
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

    context 'when a check uses a knockout parameter name' do
      subject(:compliance_engine) { described_class.new('test_module_00') }

      before(:each) do
        setup_module('test_module_00', {
                       'a.yaml' => <<~YAML,
                         ---
                         version: 2.0.0
                         profiles:
                           base_profile:
                             ces:
                               base_ce: true
                         ce:
                           base_ce:
                             controls:
                               control_a: true
                         checks:
                           set_param:
                             type: puppet-class-parameter
                             settings:
                               parameter: mymodule::param
                               value: original_value
                             ces:
                               - base_ce
                       YAML
          'b.yaml' => <<~YAML,
            ---
            version: 2.0.0
            profiles:
              knockout_profile:
                ces:
                  knockout_ce: true
            ce:
              knockout_ce:
                controls:
                  control_b: true
            checks:
              knockout_param:
                type: puppet-class-parameter
                settings:
                  parameter: "--mymodule::param"
                  value: ~
                ces:
                  - knockout_ce
          YAML
                     })
      end

      it 'knocks out the parameter when both profiles are requested' do
        hiera = compliance_engine.hiera(['base_profile', 'knockout_profile'])
        expect(hiera).not_to have_key('mymodule::param')
        expect(hiera).not_to have_key('--mymodule::param')
      end

      it 'still returns the parameter when only the base profile is requested' do
        hiera = compliance_engine.hiera(['base_profile'])
        expect(hiera).to include('mymodule::param' => 'original_value')
      end
    end
  end

  context 'data updates' do
    subject(:compliance_engine) { described_class.new }

    let(:module_path) { 'update_test_module' }
    let(:compliance_dir) { "#{module_path}/SIMP/compliance_profiles" }
    let(:file_a_path) { "#{compliance_dir}/a.yaml" }
    let(:file_b_path) { "#{compliance_dir}/b.yaml" }

    let(:file_a_contents) do
      <<~YAML
        ---
        version: 2.0.0
        profiles:
          profile_a:
            ces:
              ce_a: true
        ce:
          ce_a:
            controls:
              control_a: true
        checks:
          check_a:
            type: puppet-class-parameter
            settings:
              parameter: mymodule::param_a
              value: value_a
            ces:
              - ce_a
      YAML
    end

    let(:file_b_contents) do
      <<~YAML
        ---
        version: 2.0.0
        profiles:
          profile_b:
            ces:
              ce_b: true
        ce:
          ce_b:
            controls:
              control_b: true
        checks:
          check_b:
            type: puppet-class-parameter
            settings:
              parameter: mymodule::param_b
              value: value_b
            ces:
              - ce_b
      YAML
    end

    def stub_module(glob_results)
      allow(File).to receive(:directory?).and_call_original
      allow(File).to receive(:exist?).and_call_original
      allow(Dir).to receive(:glob).and_call_original
      allow(File).to receive(:directory?).with(module_path).and_return(true)
      allow(File).to receive(:directory?).with("#{module_path}/SIMP/compliance_profiles").and_return(true)
      allow(File).to receive(:directory?).with("#{module_path}/simp/compliance_profiles").and_return(false)
      allow(File).to receive(:exist?).with("#{module_path}/metadata.json").and_return(false)
      allow(Dir).to receive(:glob).with("#{compliance_dir}/**/*.yaml").and_return(*glob_results)
      allow(Dir).to receive(:glob).with("#{compliance_dir}/**/*.json").and_return([])

      [[file_a_path, file_a_contents], [file_b_path, file_b_contents]].each do |path, contents|
        allow(File).to receive(:size).with(path).and_return(contents.length)
        allow(File).to receive(:mtime).with(path).and_return(Time.now)
        allow(File).to receive(:read).with(path).and_return(contents)
      end
    end

    context 'when a new file is added between scans' do
      before(:each) { stub_module([[file_a_path], [file_a_path, file_b_path]]) }

      it 'picks up the new profile on re-scan' do
        compliance_engine.open(module_path)
        expect(compliance_engine.profiles.keys).to contain_exactly('profile_a')
        expect(compliance_engine.files).to contain_exactly(file_a_path)
        expect(compliance_engine.hiera(['profile_a'])).to eq({ 'mymodule::param_a' => 'value_a' })

        compliance_engine.open(module_path)
        expect(compliance_engine.profiles.keys).to contain_exactly('profile_a', 'profile_b')
        expect(compliance_engine.files).to contain_exactly(file_a_path, file_b_path)
        expect(compliance_engine.hiera(['profile_b'])).to eq({ 'mymodule::param_b' => 'value_b' })
      end
    end

    context 'when a file is deleted between scans' do
      before(:each) { stub_module([[file_a_path, file_b_path], [file_a_path]]) }

      it 'drops data from the deleted file on re-scan' do
        compliance_engine.open(module_path)
        expect(compliance_engine.profiles.keys).to contain_exactly('profile_a', 'profile_b')
        expect(compliance_engine.files).to contain_exactly(file_a_path, file_b_path)
        expect(compliance_engine.hiera(['profile_b'])).to eq({ 'mymodule::param_b' => 'value_b' })

        compliance_engine.open(module_path)
        expect(compliance_engine.profiles.keys).to contain_exactly('profile_a')
        expect(compliance_engine.files).to contain_exactly(file_a_path)
        expect(compliance_engine.hiera(['profile_b'])).to eq({})
      end
    end

    context 'when all files in a module are deleted between scans' do
      before(:each) { stub_module([[file_a_path, file_b_path], []]) }

      it 'drops all module data on re-scan' do
        compliance_engine.open(module_path)
        expect(compliance_engine.profiles.keys).to contain_exactly('profile_a', 'profile_b')

        compliance_engine.open(module_path)
        expect(compliance_engine.profiles.keys).to be_empty
        expect(compliance_engine.files).to be_empty
      end
    end
  end

  context 'zip data updates' do
    subject(:compliance_engine) { described_class.new }

    let(:zip_path) { 'test_env.zip' }
    let(:module_path) { '/zip_test_module' }
    let(:compliance_dir) { "#{module_path}/SIMP/compliance_profiles" }
    let(:file_a_path) { "#{compliance_dir}/a.yaml" }
    let(:file_b_path) { "#{compliance_dir}/b.yaml" }

    let(:file_a_contents) do
      <<~YAML
        ---
        version: 2.0.0
        profiles:
          profile_a:
            ces:
              ce_a: true
        ce:
          ce_a:
            controls:
              control_a: true
        checks:
          check_a:
            type: puppet-class-parameter
            settings:
              parameter: mymodule::param_a
              value: value_a
            ces:
              - ce_a
      YAML
    end

    let(:file_b_contents) do
      <<~YAML
        ---
        version: 2.0.0
        profiles:
          profile_b:
            ces:
              ce_b: true
        ce:
          ce_b:
            controls:
              control_b: true
        checks:
          check_b:
            type: puppet-class-parameter
            settings:
              parameter: mymodule::param_b
              value: value_b
            ces:
              - ce_b
      YAML
    end

    def make_zip_loaders(first_glob, second_glob)
      allow(File).to receive(:directory?).and_call_original
      allow(File).to receive(:exist?).and_call_original
      allow(Dir).to receive(:glob).and_call_original
      allow(File).to receive(:directory?).with(module_path).and_return(true)
      allow(File).to receive(:directory?).with("#{module_path}/SIMP/compliance_profiles").and_return(true)
      allow(File).to receive(:directory?).with("#{module_path}/simp/compliance_profiles").and_return(false)
      allow(File).to receive(:exist?).with("#{module_path}/metadata.json").and_return(false)
      allow(Dir).to receive(:glob).with("#{compliance_dir}/**/*.yaml").and_return(first_glob, second_glob)
      allow(Dir).to receive(:glob).with("#{compliance_dir}/**/*.json").and_return([])

      [[file_a_path, file_a_contents], [file_b_path, file_b_contents]].each do |path, contents|
        allow(File).to receive(:size).with(path).and_return(contents.length)
        allow(File).to receive(:mtime).with(path).and_return(Time.now)
        allow(File).to receive(:read).with(path).and_return(contents)
      end

      first = ComplianceEngine::ModuleLoader.new(module_path, zipfile_path: zip_path)
      second = ComplianceEngine::ModuleLoader.new(module_path, zipfile_path: zip_path)
      [first, second]
    end

    context 'when a file is deleted between scans' do
      it 'drops data from the deleted file on re-scan' do
        first_loader, second_loader = make_zip_loaders([file_a_path, file_b_path], [file_a_path])

        compliance_engine.open(first_loader)
        expect(compliance_engine.profiles.keys).to contain_exactly('profile_a', 'profile_b')

        compliance_engine.open(second_loader)
        expect(compliance_engine.profiles.keys).to contain_exactly('profile_a')
        expect(compliance_engine.hiera(['profile_b'])).to eq({})
      end
    end

    context 'when all files in a zip module are deleted between scans' do
      it 'drops all module data on re-scan' do
        first_loader, second_loader = make_zip_loaders([file_a_path, file_b_path], [])

        compliance_engine.open(first_loader)
        expect(compliance_engine.profiles.keys).to contain_exactly('profile_a', 'profile_b')

        compliance_engine.open(second_loader)
        expect(compliance_engine.profiles.keys).to be_empty
        expect(compliance_engine.files).to be_empty
      end
    end
  end
end
