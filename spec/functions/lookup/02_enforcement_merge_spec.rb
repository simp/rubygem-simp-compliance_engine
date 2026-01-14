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
      'version' => '2.0.0',
      'profiles' => {
        '02_profile_test' => {
          'controls' => {
            '02_control1' => true,
          },
        },
      },
    }.to_yaml
  end

  let(:ces_yaml) do
    {
      'version' => '2.0.0',
      'ce' => {
        '02_ce1' => {
          'controls' => {
            '02_control1' => true,
          },
        },
      },
    }.to_yaml
  end

  let(:checks_yaml) do
    {
      'version' => '2.0.0',
      'checks'  => {
        '02_array check1' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_02::array_param',
            'value'     => [
              'array value 1',
            ],
          },
          'ces' => [
            '02_ce1',
          ],
        },
        '02_array check2' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_02::array_param',
            'value'     => [
              'array value 2',
            ],
          },
          'ces' => [
            '02_ce1',
          ],
        },
        '02_hash check1' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_02::hash_param',
            'value'     => {
              'hash key 1' => 'hash value 1',
            },
          },
          'ces' => [
            '02_ce1',
          ],
        },
        '02_hash check2' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_02::hash_param',
            'value'     => {
              'hash key 2' => 'hash value 2',
            },
          },
          'ces' => [
            '02_ce1',
          ],
        },
        '02_nested hash1' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_02::nested_hash',
            'value'     => {
              'key' => {
                'key1' => 'value1',
              },
            },
          },
          'ces' => [
            '02_ce1',
          ],
        },
        '02_nested hash2' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_02::nested_hash',
            'value'     => {
              'key' => {
                'key2' => 'value2',
              },
            },
          },
          'ces' => [
            '02_ce1',
          ],
        },
      },
    }.to_yaml
  end

  let(:tmpdir) { Dir.mktmpdir('compliance_engine_test') }
  let(:test_module_path) { File.join(tmpdir, 'test_module_02') }
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
        os_facts.merge('target_compliance_profile' => '02_profile_test')
      end

      let(:hieradata) { 'compliance-engine' }

      # Test a simple array.
      it { is_expected.to run.with_params('test_module_02::array_param').and_return(['array value 1', 'array value 2']) }

      # Test a simple hash.
      it { is_expected.to run.with_params('test_module_02::hash_param').and_return({ 'hash key 1' => 'hash value 1', 'hash key 2' => 'hash value 2' }) }

      # Test a nested hash.
      it { is_expected.to run.with_params('test_module_02::nested_hash').and_return({ 'key' => { 'key1' => 'value1', 'key2' => 'value2' } }) }
    end
  end
end
