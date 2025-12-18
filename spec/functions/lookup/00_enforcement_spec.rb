#!/usr/bin/env ruby -S rspec

require 'spec_helper'
require 'spec_helper_puppet'
# require 'semantic_puppet'
# require 'puppet/pops/lookup/context'
require 'yaml'
# require 'fileutils'

RSpec.describe 'lookup' do
  # Generate a fake module with dummy data for lookup().
  let(:profile_yaml) do
    {
      'version' => '2.0.0',
      'profiles' => {
        '00_profile_test' => {
          'controls' => {
            '00_control1' => true,
          },
        },
        '00_profile_with_check_reference' => {
          'checks' => {
            '00_check2' => true,
          },
        },
      },
    }.to_yaml
  end

  let(:ces_yaml) do
    {
      'version' => '2.0.0',
      'ce' => {
        '00_ce1' => {
          'controls' => {
            '00_control1' => true,
          },
        },
      },
    }.to_yaml
  end

  let(:checks_yaml) do
    {
      'version' => '2.0.0',
      'checks' => {
        '00_check1' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_00::test_param',
            'value'     => 'a string',
          },
          'ces' => [
            '00_ce1',
          ],
        },
        '00_check2' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_00::test_param2',
            'value'     => 'another string',
          },
          'ces' => [
            '00_ce1',
          ],
        },
      },
    }.to_yaml
  end

  let(:fixtures) { File.expand_path('../../fixtures', __dir__) }

  let(:module_path) { File.join(fixtures, 'modules', 'test_module_00') }
  let(:compliance_dir) { File.join(module_path, 'SIMP', 'compliance_profiles') }
  let(:compliance_files) { ['profile.yaml', 'ces.yaml', 'checks.yaml'].map { |f| File.join(compliance_dir, f) } }

  before(:each) do
    allow(Dir).to receive(:glob).and_call_original
    allow(File).to receive(:directory?).and_call_original
    allow(File).to receive(:directory?).with(Pathname.new(File.join(fixtures, 'modules'))).and_return(true)
    allow(File).to receive(:directory?).with(module_path).and_return(true)
    allow(File).to receive(:directory?).with("#{module_path}/SIMP/compliance_profiles").and_return(true)
    allow(File).to receive(:directory?).with("#{module_path}/simp/compliance_profiles").and_return(false)
    allow(Dir).to receive(:glob)
      .with("#{module_path}/SIMP/compliance_profiles/**/*.yaml")
      .and_return(
        compliance_files,
      )
    allow(Dir).to receive(:glob)
      .with("#{module_path}/SIMP/compliance_profiles/**/*.json")
      .and_return([])

    allow(File).to receive(:size).and_call_original
    allow(File).to receive(:mtime).and_call_original
    allow(File).to receive(:read).and_call_original

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

  on_supported_os.each do |os, os_facts|
    context "on #{os} with compliance_engine::enforcement and a non-existent profile" do
      let(:facts) do
        os_facts.merge('target_compliance_profile' => 'not_a_profile')
      end

      let(:hieradata) { 'compliance-engine' }

      it {
        is_expected.to run.with_params('test_module_00::test_param')
                          .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_00::test_param'")
      }
    end

    context "on #{os} with compliance_engine::enforcement and an existing profile" do
      let(:facts) do
        os_facts.merge('target_compliance_profile' => '00_profile_test')
      end

      let(:hieradata) { 'compliance-engine' }

      # Test unconfined data.
      it { is_expected.to run.with_params('test_module_00::test_param').and_return('a string') }
      it { is_expected.to run.with_params('test_module_00::test_param2').and_return('another string') }
    end

    context "on #{os} with compliance_engine::enforcement and a profile directly referencing a check" do
      let(:facts) do
        os_facts.merge('target_compliance_profile' => '00_profile_with_check_reference')
      end

      let(:hieradata) { 'compliance-engine' }

      # Test unconfined data.
      it {
        is_expected.to run.with_params('test_module_00::test_param')
                          .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_00::test_param'")
      }
      it { is_expected.to run.with_params('test_module_00::test_param2').and_return('another string') }
    end
  end
end
