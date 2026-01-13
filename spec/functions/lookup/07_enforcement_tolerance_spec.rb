#!/usr/bin/env ruby -S rspec
# frozen_string_literal: true

require 'spec_helper'
require 'spec_helper_puppet'
require 'yaml'
require 'fileutils'
require 'tmpdir'

RSpec.describe 'lookup' do
  # Generate a fake module with dummy data for lookup().
  let(:profile_yaml) do
    {
      'version'  => '2.0.0',
      'profiles' => {
        '07_profile_test' => {
          'controls' => {
            '07_control1'   => true,
            '07_os_control' => true,
          },
        },
      },
    }.to_yaml
  end

  let(:ces_yaml) do
    {
      'version' => '2.0.0',
      'ce'      => {
        '07_ce1' => {
          'controls' => {
            '07_control1' => true,
          },
        },
        '07_ce2' => {
          'controls' => {
            '07_os_control' => true,
          },
        },
      },
    }.to_yaml
  end

  let(:checks_yaml) do
    {
      'version' => '2.0.0',
      'checks'  => {
        '07_disabled_check' => {
          'type' => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_07::is_disabled',
            'value'     => true,
          },
          'ces' => [
            '07_ce2',
          ],
          'remediation' => {
            'disabled' => [
              { 'reason' => 'This is the reason this check is disabled.' },
            ]
          },
        },
        '07_level_21_check' => {
          'type' => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_07::is_level_21',
            'value'     => true,
          },
          'ces' => [
            '07_ce2',
          ],
          'remediation' => {
            'risk' => [
              { 'level' => 21 },
            ]
          },
        },
        '07_level_41_check' => {
          'type' => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_07::is_level_41',
            'value'     => true,
          },
          'ces' => [
            '07_ce2',
          ],
          'remediation' => {
            'risk' => [
              { 'level' => 41, 'reason' => 'this is the reason for level 41' },
            ]
          },
        },
        '07_level_61_check' => {
          'type' => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_07::is_level_61',
            'value'     => true,
          },
          'ces' => [
            '07_ce2',
          ],
          'remediation' => {
            'risk' => [
              { 'level' => 61, 'reason' => 'this is the reason for level 61' },
            ]
          },
        },
        '07_level_81_check' => {
          'type' => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_07::is_level_81',
            'value'     => true,
          },
          'ces' => [
            '07_ce2',
          ],
          'remediation' => {
            'risk' => [
              { 'level' => 81, 'reason' => 'this is the reason for level 81' },
            ]
          },
        },
      },
    }.to_yaml
  end

  let(:tmpdir) { Dir.mktmpdir('compliance_engine_test_07') }
  let(:test_module_path) { File.join(tmpdir, 'test_module_07') }
  let(:compliance_dir) { File.join(test_module_path, 'SIMP', 'compliance_profiles') }

  before(:each) do
    # Create the directory structure
    FileUtils.mkdir_p(compliance_dir)

    # Write the test data files
    File.write(File.join(compliance_dir, 'profiles.yaml'), profile_yaml)
    File.write(File.join(compliance_dir, 'ces.yaml'), ces_yaml)
    File.write(File.join(compliance_dir, 'checks.yaml'), checks_yaml)

    # Mock the Puppet environment's modulepath to include our temp directory
    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(Puppet::Node::Environment).to receive(:full_modulepath).and_return([tmpdir])
    # rubocop:enable RSpec/AnyInstance
  end

  after(:each) do
    # Clean up temporary directory
    FileUtils.rm_rf(tmpdir) if tmpdir && File.exist?(tmpdir)
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os} with compliance_engine::enforcement and an existing profile using tolerance above level 21" do
      let(:facts) do
        os_facts.merge(
          'custom_hiera'                 => 'compliance_engine',
          'target_compliance_profile'    => '07_profile_test',
          'target_enforcement_tolerance' => '22'
        )
      end
      let(:hieradata) { 'compliance_engine' }

      it do
        is_expected.to run.with_params('test_module_07::is_disabled')
                          .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_07::is_disabled'")
      end

      it { is_expected.to run.with_params('test_module_07::is_level_21').and_return(true) }

      it do
        is_expected.to run.with_params('test_module_07::is_level_41')
                          .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_07::is_level_41'")
      end

      it do
        is_expected.to run.with_params('test_module_07::is_level_61')
                          .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_07::is_level_61'")
      end

      it do
        is_expected.to run.with_params('test_module_07::is_level_81')
                          .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_07::is_level_81'")
      end
    end

    context "on #{os} with compliance_engine::enforcement and an existing profile using tolerance above level 41" do
      let(:facts) do
        os_facts.merge('custom_hiera' => 'compliance_engine', 'target_compliance_profile' => '07_profile_test', 'target_enforcement_tolerance' => '42')
      end
      let(:hieradata) { 'compliance_engine' }

      it do
        is_expected.to run.with_params('test_module_07::is_disabled')
                          .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_07::is_disabled'")
      end

      it { is_expected.to run.with_params('test_module_07::is_level_21').and_return(true) }
      it { is_expected.to run.with_params('test_module_07::is_level_41').and_return(true) }

      it do
        is_expected.to run.with_params('test_module_07::is_level_61')
                          .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_07::is_level_61'")
      end

      it do
        is_expected.to run.with_params('test_module_07::is_level_81')
                          .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_07::is_level_81'")
      end
    end

    context "on #{os} with compliance_engine::enforcement and an existing profile using tolerance above level 61" do
      let(:facts) do
        os_facts.merge('custom_hiera' => 'compliance_engine', 'target_compliance_profile' => '07_profile_test', 'target_enforcement_tolerance' => '62')
      end
      let(:hieradata) { 'compliance_engine' }

      it do
        is_expected.to run.with_params('test_module_07::is_disabled')
                          .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_07::is_disabled'")
      end

      it { is_expected.to run.with_params('test_module_07::is_level_21').and_return(true) }
      it { is_expected.to run.with_params('test_module_07::is_level_41').and_return(true) }
      it { is_expected.to run.with_params('test_module_07::is_level_61').and_return(true) }

      it do
        is_expected.to run.with_params('test_module_07::is_level_81')
                          .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_07::is_level_81'")
      end
    end

    context "on #{os} with compliance_engine::enforcement and an existing profile using tolerance above level 81" do
      let(:facts) do
        os_facts.merge('custom_hiera' => 'compliance_engine', 'target_compliance_profile' => '07_profile_test', 'target_enforcement_tolerance' => '82')
      end
      let(:hieradata) { 'compliance_engine' }

      it do
        is_expected.to run.with_params('test_module_07::is_disabled')
                          .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_07::is_disabled'")
      end

      it { is_expected.to run.with_params('test_module_07::is_level_21').and_return(true) }
      it { is_expected.to run.with_params('test_module_07::is_level_41').and_return(true) }
      it { is_expected.to run.with_params('test_module_07::is_level_61').and_return(true) }
      it { is_expected.to run.with_params('test_module_07::is_level_81').and_return(true) }
    end
  end
end
