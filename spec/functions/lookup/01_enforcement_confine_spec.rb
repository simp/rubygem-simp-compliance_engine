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
        '01_profile_test' => {
          'controls' => {
            '01_control1'   => true,
            '01_os_control' => true,
          },
        },
      },
    }.to_yaml
  end

  let(:ces_yaml) do
    {
      'version' => '2.0.0',
      'ce'      => {
        '01_ce1' => {
          'controls' => {
            '01_control1' => true,
          },
        },
        '01_ce2' => {
          'controls' => {
            '01_os_control' => true,
          },
        },
        '01_ce3' => {
          'controls' => {
            '01_control1' => true,
          },
          'confine' => {
            'module_name'    => 'simp-compliance_engine',
            'module_version' => '< 3.1.0',
          },
        },
      },
    }.to_yaml
  end

  let(:checks_yaml) do
    {
      'version' => '2.0.0',
      'checks'  => {
        '01_el_check' => {
          'type' => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_01::is_el',
            'value'     => true,
          },
          'ces' => [
            '01_ce2',
          ],
          'confine' => {
            'os.family' => 'RedHat',
          },
        },
        '01_el_negative_check' => {
          'type' => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_01::is_not_el',
            'value'     => true,
          },
          'ces' => [
            '01_ce2',
          ],
          'confine' => {
            'os.family' => '!RedHat',
          },
        },
        '01_el7_check' => {
          'type' => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_01::el_version',
            'value'     => '7',
          },
          'ces' => [
            '01_ce2',
          ],
          'confine' => {
            'os.name' => [
              'RedHat',
              'CentOS'
            ],
            'os.release.major' => '7',
          },
        },
        '01_el7_negative_check' => {
          'type' => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_01::not_el_version',
            'value'     => '7',
          },
          'ces' => [
            '01_ce2',
          ],
          'confine' => {
            'os.name' => [
              '!RedHat',
            ],
            'os.release.major' => '7',
          },
        },
        '01_el7_negative_mixed_check' => {
          'type' => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_01::not_el_centos_version',
            'value'     => '7',
          },
          'ces' => [
            '01_ce2',
          ],
          'confine' => {
            'os.name' => [
              '!RedHat',
              'CentOS',
            ],
            'os.release.major' => '7',
          },
        },
        '01_confine_in_ces' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_01::fixed_confines',
            'value'     => false,
          },
          'ces' => [
            '01_ce3',
          ],
        },
      },
    }.to_yaml
  end

  let(:tmpdir) { Dir.mktmpdir('compliance_engine_test') }
  let(:test_module_path) { File.join(tmpdir, 'test_module_01') }
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
    FileUtils.rm_rf(tmpdir)
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os} with compliance_engine::enforcement and an existing profile" do
      let(:facts) do
        os_facts.merge('target_compliance_profile' => '01_profile_test')
      end

      let(:hieradata) { 'compliance_engine' }

      # Test for confine on a single fact in checks.
      if os_facts[:os]['family'] == 'RedHat'
        it { is_expected.to run.with_params('test_module_01::is_el').and_return(true) }
      else
        it { is_expected.to run.with_params('test_module_01::is_el').and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_01::is_el'") }
      end

      # Test for confine on a single fact in checks.
      if os_facts[:os]['family'] == 'RedHat'
        it do
          is_expected.to run.with_params('test_module_01::is_not_el')
                            .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_01::is_not_el'")
        end
      else
        it { is_expected.to run.with_params('test_module_01::is_not_el').and_return(true) }
      end

      # Test for confine on multiple facts and an array of facts in checks.
      if ['RedHat', 'CentOS'].include?(os_facts[:os]['name']) && os_facts[:os]['release']['major'] == '7'
        it { is_expected.to run.with_params('test_module_01::el_version').and_return('7') }
      else
        it do
          is_expected.to run.with_params('test_module_01::el_version')
                            .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_01::el_version'")
        end
      end

      # Test for confine on multiple facts and a negative fact match.
      if (os_facts[:os]['name'] != 'RedHat') && os_facts[:os]['release']['major'] == '7'
        it { is_expected.to run.with_params('test_module_01::not_el_version').and_return('7') }
      else
        it do
          is_expected.to run.with_params('test_module_01::not_el_version')
                            .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_01::not_el_version'")
        end
      end

      # Test for confine on multiple facts and a negative fact match mixed with a positive one.
      # TODO: This does not currently work as one might expect. This will still positively match OracleLinux even though
      # we ask for OS names that aren't RedHat but are CentOS. The array we're confining can only do an OR operation rather
      # than an AND with a negative lookup.
      # rubocop:disable RSpec/RepeatedExample
      if (os_facts[:os]['name'] != 'RedHat') && (os_facts[:os]['name'] == 'CentOS') && os_facts[:os]['release']['major'] == '7'
        it { is_expected.to run.with_params('test_module_01::not_el_centos_version').and_return('7') }
      elsif (os_facts[:os]['name'] != 'RedHat') && (os_facts[:os]['name'] != 'CentOS') && os_facts[:os]['release']['major'] == '7'
        it { is_expected.to run.with_params('test_module_01::not_el_centos_version').and_return('7') }
      else
        it do
          is_expected.to run.with_params('test_module_01::not_el_centos_version')
                            .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_01::not_el_centos_version'")
        end
      end
      # rubocop:enable RSpec/RepeatedExample

      # Test for confine on module name & module version in ce.
      it do
        is_expected.to run.with_params('test_module_01::fixed_confines')
                          .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_01::fixed_confines'")
      end
    end
  end
end
