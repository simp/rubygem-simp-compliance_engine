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
        'profile_test1' => {
          'ces' => {
            '03_profile_test1' => true,
          },
        },
        'profile_test2' => {
          'ces' => {
            '03_profile_test2' => true,
          },
        },
      },
    }.to_yaml
  end

  let(:ces_yaml) do
    {
      'version' => '2.0.0',
      'ce'      => {
        '03_profile_test1' => {},
        '03_profile_test2' => {},
      },
    }.to_yaml
  end

  let(:checks_yaml) do
    {
      'version' => '2.0.0',
      'checks'  => {
        '03_string check1' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_03::string_param',
            'value'     => 'string value 1',
          },
          'ces' => [
            '03_profile_test1',
          ],
        },
        '03_string check2' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_03::string_param',
            'value'     => 'string value 2',
          },
          'ces' => [
            '03_profile_test2',
          ],
        },
        '03_array check1' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_03::array_param',
            'value'     => [
              'array value 1',
            ],
          },
          'ces' => [
            '03_profile_test1',
          ],
        },
        '03_array check2' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_03::array_param',
            'value'     => [
              'array value 2',
            ],
          },
          'ces' => [
            '03_profile_test2',
          ],
        },
        '03_hash check1' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_03::hash_param',
            'value'     => {
              'hash key 1' => 'hash value 1',
            },
          },
          'ces' => [
            '03_profile_test1',
          ],
        },
        '03_hash check2' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_03::hash_param',
            'value'     => {
              'hash key 2' => '\-- hash value 2',
            },
          },
          'ces' => [
            '03_profile_test2',
          ],
        },
        '03_nested hash1' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_03::nested_hash',
            'value'     => {
              'key' => {
                'key1' => 'value1',
              },
            },
          },
          'ces' => [
            '03_profile_test1',
          ],
        },
        '03_nested hash2' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_03::nested_hash',
            'value'     => {
              'key' => {
                'key1' => 'value2',
                'key2' => 'value2',
              },
            },
          },
          'ces' => [
            '03_profile_test2',
          ],
        },
      },
    }.to_yaml
  end

  let(:tmpdir) { Dir.mktmpdir('compliance_engine_test') }
  let(:test_module_path) { File.join(tmpdir, 'test_module_03') }
  let(:compliance_dir) { File.join(test_module_path, 'SIMP', 'compliance_profiles') }
  let(:hieradata_dir) { File.expand_path('../../data', __dir__) }
  let(:hieradata_file) { "profile-merging-#{Process.pid}" }

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
    context "on #{os} with compliance_engine::enforcement merging profiles" do
      let(:facts) { os_facts.merge('custom_hiera' => hieradata_file) }
      let(:hieradata) { hieradata_file }

      before(:each) do
        File.open(File.join(hieradata_dir, "#{hieradata_file}.yaml"), 'w') do |fh|
          test_hiera = { 'compliance_engine::enforcement' => ['profile_test1', 'profile_test2'] }.to_yaml
          fh.puts test_hiera
        end
      end

      after(:each) do
        FileUtils.rm_f(File.join(hieradata_dir, "#{hieradata_file}.yaml"))
      end

      # Test a string.
      it { is_expected.to run.with_params('test_module_03::string_param').and_return('string value 1') }

      # Test a simple array.
      it { is_expected.to run.with_params('test_module_03::array_param').and_return(['array value 2', 'array value 1']) }

      # Test a simple hash.
      it { is_expected.to run.with_params('test_module_03::hash_param').and_return({ 'hash key 1' => 'hash value 1', 'hash key 2' => '\-- hash value 2' }) }

      # Test a nested hash.
      it { is_expected.to run.with_params('test_module_03::nested_hash').and_return({ 'key' => { 'key1' => 'value1', 'key2' => 'value2' } }) }
    end

    context "on #{os} with compliance_engine::enforcement merging profiles in reverse order" do
      let(:facts) { os_facts.merge('custom_hiera' => hieradata_file) }
      let(:hieradata) { hieradata_file }

      before(:each) do
        File.open(File.join(hieradata_dir, "#{hieradata_file}.yaml"), 'w') do |fh|
          test_hiera = { 'compliance_engine::enforcement' => ['profile_test2', 'profile_test1'] }.to_yaml
          fh.puts test_hiera
        end
      end

      after(:each) do
        FileUtils.rm_f(File.join(hieradata_dir, "#{hieradata_file}.yaml"))
      end

      # Test a string.
      it { is_expected.to run.with_params('test_module_03::string_param').and_return('string value 2') }

      # Test a simple array.
      it { is_expected.to run.with_params('test_module_03::array_param').and_return(['array value 1', 'array value 2']) }

      # Test a simple hash.
      it { is_expected.to run.with_params('test_module_03::hash_param').and_return({ 'hash key 2' => '\-- hash value 2', 'hash key 1' => 'hash value 1' }) }

      # Test a nested hash.
      it { is_expected.to run.with_params('test_module_03::nested_hash').and_return({ 'key' => { 'key1' => 'value2', 'key2' => 'value2' } }) }
    end
  end
end
