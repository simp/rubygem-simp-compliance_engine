# frozen_string_literal: true

# Shared context for mocking compliance module file system operations
RSpec.shared_context 'compliance module mocks' do |module_name|
  let(:fixtures) { File.expand_path('../../fixtures', __dir__) }
  let(:module_path) { File.join(fixtures, 'modules', module_name) }
  let(:compliance_dir) { File.join(module_path, 'SIMP', 'compliance_profiles') }
  let(:compliance_files) { ['profile.yaml', 'ces.yaml', 'checks.yaml'].map { |f| File.join(compliance_dir, f) } }

  before(:each) do
    allow(Dir).to receive(:glob).and_call_original
    allow(Dir).to receive(:entries).and_call_original
    allow(File).to receive(:directory?).and_call_original
    allow(File).to receive(:exist?).and_call_original

    # Mock the modulepath directory entries to include the test module
    allow(Dir).to receive(:entries).with(File.join(fixtures, 'modules')).and_return(['.', '..', 'compliance_engine', module_name])

    allow(File).to receive(:directory?).with(Pathname.new(File.join(fixtures, 'modules'))).and_return(true)
    allow(File).to receive(:directory?).with(File.join(fixtures, 'modules', module_name)).and_return(true)
    allow(File).to receive(:directory?).with(module_path).and_return(true)
    allow(File).to receive(:directory?).with("#{module_path}/SIMP/compliance_profiles").and_return(true)
    allow(File).to receive(:directory?).with("#{module_path}/simp/compliance_profiles").and_return(false)

    # Mock metadata.json existence check (default to not existing unless overridden)
    metadata_path = File.join(module_path, 'metadata.json')
    allow(File).to receive(:exist?).with(metadata_path).and_return(defined?(metadata_json) && !metadata_json.nil?)
    if defined?(metadata_json) && metadata_json
      allow(File).to receive(:read).with(metadata_path).and_return(metadata_json)
    end

    allow(Dir).to receive(:glob).
      with("#{module_path}/SIMP/compliance_profiles/**/*.yaml").
      and_return(compliance_files)
    allow(Dir).to receive(:glob).
      with("#{module_path}/SIMP/compliance_profiles/**/*.json").
      and_return([])

    allow(File).to receive(:size).and_call_original
    allow(File).to receive(:mtime).and_call_original
    allow(File).to receive(:read).and_call_original

    # Mock compliance data files
    allow(File).to receive(:size).with(File.join(compliance_dir, 'profile.yaml')).and_return(profile_yaml.length)
    allow(File).to receive(:mtime).with(File.join(compliance_dir, 'profile.yaml')).and_return(Time.now)
    allow(File).to receive(:read).with(File.join(compliance_dir, 'profile.yaml')).and_return(profile_yaml)

    allow(File).to receive(:size).with(File.join(compliance_dir, 'ces.yaml')).and_return(ces_yaml.length)
    allow(File).to receive(:mtime).with(File.join(compliance_dir, 'ces.yaml')).and_return(Time.now)
    allow(File).to receive(:read).with(File.join(compliance_dir, 'ces.yaml')).and_return(ces_yaml)

    allow(File).to receive(:size).with(File.join(compliance_dir, 'checks.yaml')).and_return(checks_yaml.length)
    allow(File).to receive(:mtime).with(File.join(compliance_dir, 'checks.yaml')).and_return(Time.now)
    allow(File).to receive(:read).with(File.join(compliance_dir, 'checks.yaml')).and_return(checks_yaml)
  end
end
