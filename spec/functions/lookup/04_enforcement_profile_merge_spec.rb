#!/usr/bin/env ruby -S rspec
# frozen_string_literal: true

require 'spec_helper'
require 'spec_helper_puppet'
require 'yaml'
require 'fileutils'
require 'tmpdir'

RSpec.describe 'lookup' do
  # Generate a fake module with dummy data for lookup().
  # Break it up between multiple files to validate merging.
  let(:files) do
    {
      'profile_00' => {
        'version'  => '2.0.0',
        'profiles' => {
          'profile_test1' => {
            'ces' => {
              '04_profile_test1' => true,
            },
          },
        },
      },
      'profile_01' => {
        'version'  => '2.0.0',
        'profiles' => {
          'profile_test2' => {
            'ces' => {
              '04_profile_test2' => true,
            },
          },
        },
      },
      'ces_00' => {
        'version' => '2.0.0',
        'ce'      => {
          '04_profile_test1' => {
            'controls' => {
              '04_control1' => true,
            },
            'oval-ids' => [
              - '04_oval_id1',
            ],
          },
        },
      },
      'ces_01' => {
        'version' => '2.0.0',
        'ce'      => {
          '04_profile_test2' => {
            'identifiers' => {
              '04_identifier1' => [],
            },
          },
        },
      },
      'checks_00' => {
        'version' => '2.0.0',
        'checks'  => {
          '04_string check1' => {
            'ces' => [
              '04_profile_test1',
            ],
            'controls' => {
              '04_control2' => true,
            },
          },
        },
      },
      'checks_01' => {
        'version' => '2.0.0',
        'checks'  => {
          '04_string check1' => {
            'type' => 'puppet-class-parameter',
          },
        },
      },
      'checks_02' => {
        'version' => '2.0.0',
        'checks'  => {
          '04_string check1' => {
            'settings' => {
              'value' => 'string value 1',
            },
          },
        },
      },
      'checks_03' => {
        'version' => '2.0.0',
        'checks'  => {
          '04_string check1' => {
            'settings' => {
              'parameter' => 'test_module_04::string_param',
            },
          },
        },
      },
      'checks_10' => {
        'version' => '2.0.0',
        'checks'  => {
          '04_string check2' => {
            'settings' => {
              'parameter' => 'test_module_04::string_param',
            },
          },
        },
      },
      'checks_11' => {
        'version' => '2.0.0',
        'checks'  => {
          '04_string check2' => {
            'settings' => {
              'value' => 'string value 2',
            },
            'identifiers' => {
              '04_identifier2' => [],
            },
          },
        },
      },
      'checks_12' => {
        'version' => '2.0.0',
        'checks'  => {
          '04_string check2' => {
            'type' => 'puppet-class-parameter',
          },
        },
      },
      'checks_13' => {
        'version' => '2.0.0',
        'checks'  => {
          '04_string check2' => {
            'ces' => [
              '04_profile_test2',
            ],
          },
        },
      },
      'checks_20' => {
        'version' => '2.0.0',
        'checks'  => {
          '04_array check1' => {
            'type' => 'puppet-class-parameter',
          },
        },
      },
      'checks_21' => {
        'version' => '2.0.0',
        'checks'  => {
          '04_array check1' => {
            'ces' => [
              '04_profile_test1',
            ],
          },
        },
      },
      'checks_22' => {
        'version' => '2.0.0',
        'checks'  => {
          '04_array check1' => {
            'settings' => {
              'value' => [
                'array value 1',
              ],
            },
            'oval-ids' => [
              - '04_oval_id2',
            ],
          },
        },
      },
      'checks_23' => {
        'version' => '2.0.0',
        'checks'  => {
          '04_array check1' => {
            'settings' => {
              'parameter' => 'test_module_04::array_param',
            },
          },
        },
      },
      'checks_30' => {
        'version' => '2.0.0',
        'checks'  => {
          '04_array check2' => {
            'settings' => {
              'value' => [
                'array value 2',
              ],
            },
          },
        },
      },
      'checks_31' => {
        'version' => '2.0.0',
        'checks'  => {
          '04_array check2' => {
            'type' => 'puppet-class-parameter',
          },
        },
      },
      'checks_32' => {
        'version' => '2.0.0',
        'checks'  => {
          '04_array check2' => {
            'ces' => [
              '04_profile_test2',
            ],
          },
        },
      },
      'checks_33' => {
        'version' => '2.0.0',
        'checks'  => {
          '04_array check2' => {
            'settings' => {
              'parameter' => 'test_module_04::array_param',
            },
            'controls' => {
              '04_control3' => true,
            },
          },
        },
      },
      'checks_40' => {
        'version' => '2.0.0',
        'checks'  => {
          '04_hash check1' => {
            'settings' => {
              'value' => {
                'hash key 1' => 'hash value 1',
              },
            },
            'identifiers' => {
              '04_identifier3' => [],
            },
          },
        },
      },
      'checks_41' => {
        'version' => '2.0.0',
        'checks'  => {
          '04_hash check1' => {
            'settings' => {
              'parameter' => 'test_module_04::hash_param',
            },
          },
        },
      },
      'checks_42' => {
        'version' => '2.0.0',
        'checks'  => {
          '04_hash check1' => {
            'ces' => [
              '04_profile_test1',
            ],
          },
        },
      },
      'checks_43' => {
        'version' => '2.0.0',
        'checks'  => {
          '04_hash check1' => {
            'type' => 'puppet-class-parameter',
          },
        },
      },
      'checks_50' => {
        'version' => '2.0.0',
        'checks'  => {
          '04_hash check2' => {
            'ces' => [
              '04_profile_test2',
            ],
          },
        },
      },
      'checks_51' => {
        'version' => '2.0.0',
        'checks'  => {
          '04_hash check2' => {
            'type'     => 'puppet-class-parameter',
            'oval-ids' => [
              - '04_oval_id3',
            ],
          },
        },
      },
      'checks_52' => {
        'version' => '2.0.0',
        'checks'  => {
          '04_hash check2' => {
            'settings' => {
              'parameter' => 'test_module_04::hash_param',
            },
          },
        },
      },
      'checks_53' => {
        'version' => '2.0.0',
        'checks'  => {
          '04_hash check2' => {
            'settings' => {
              'value' => {
                'hash key 2' => 'hash value 2',
              },
            },
          },
        },
      },
      'checks_60' => {
        'version' => '2.0.0',
        'checks'  => {
          '04_nested hash1' => {
            'settings' => {
              'parameter' => 'test_module_04::nested_hash',
            },
          },
        },
      },
      'checks_61' => {
        'version' => '2.0.0',
        'checks'  => {
          '04_nested hash1' => {
            'ces' => [
              '04_profile_test1',
            ],
          },
        },
      },
      'checks_62' => {
        'version' => '2.0.0',
        'checks'  => {
          '04_nested hash1' => {
            'settings' => {
              'value' => {
                'key' => {
                  'key1' => 'value1',
                },
              },
            },
          },
        },
      },
      'checks_63' => {
        'version' => '2.0.0',
        'checks'  => {
          '04_nested hash1' => {
            'type' => 'puppet-class-parameter',
          },
        },
      },
      'checks_70' => {
        'version' => '2.0.0',
        'checks'  => {
          '04_nested hash2' => {
            'type' => 'puppet-class-parameter',
          },
        },
      },
      'checks_71' => {
        'version' => '2.0.0',
        'checks'  => {
          '04_nested hash2' => {
            'settings' => {
              'parameter' => 'test_module_04::nested_hash',
            },
          },
        },
      },
      'checks_72' => {
        'version' => '2.0.0',
        'checks'  => {
          '04_nested hash2' => {
            'settings' => {
              'value' => {
                'key' => {
                  'key1' => 'value2',
                },
              },
            },
          },
        },
      },
      'checks_73' => {
        'version' => '2.0.0',
        'checks'  => {
          '04_nested hash2' => {
            'settings' => {
              'value' => {
                'key' => {
                  'key2' => 'value2',
                },
              },
            },
          },
        },
      },
      'checks_74' => {
        'version' => '2.0.0',
        'checks'  => {
          '04_nested hash2' => {
            'ces' => [
              '04_profile_test2',
            ],
          },
        },
      },
    }
  end

  let(:tmpdir) { Dir.mktmpdir('compliance_engine_test') }
  let(:test_module_path) { File.join(tmpdir, 'test_module_04') }
  let(:compliance_dir) { File.join(test_module_path, 'SIMP', 'compliance_profiles') }
  let(:hieradata_dir) { File.expand_path('../../data', __dir__) }

  before(:each) do
    # Create the directory structure
    FileUtils.mkdir_p(compliance_dir)

    # Write the test data files
    files.each do |file, data|
      File.write(File.join(compliance_dir, "#{file}.yaml"), data.to_yaml)
    end

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
      let(:facts) { os_facts.merge('custom_hiera' => 'profile-merging') }
      let(:hieradata) { 'profile-merging' }

      before(:each) do
        File.open(File.join(hieradata_dir, 'profile-merging.yaml'), 'w') do |fh|
          test_hiera = { 'compliance_engine::enforcement' => %w[profile_test1 profile_test2] }.to_yaml
          fh.puts test_hiera
        end
      end

      # Test a string.
      it { is_expected.to run.with_params('test_module_04::string_param').and_return('string value 1') }

      # Test a simple array.
      it { is_expected.to run.with_params('test_module_04::array_param').and_return(['array value 2', 'array value 1']) }

      # Test a simple hash.
      it { is_expected.to run.with_params('test_module_04::hash_param').and_return({ 'hash key 1' => 'hash value 1', 'hash key 2' => 'hash value 2' }) }

      # Test a nested hash.
      it { is_expected.to run.with_params('test_module_04::nested_hash').and_return({ 'key' => { 'key1' => 'value1', 'key2' => 'value2' } }) }
    end

    context "on #{os} with compliance_engine::enforcement merging profiles in reverse order" do
      let(:facts) { os_facts.merge('custom_hiera' => 'profile-merging') }
      let(:hieradata) { 'profile-merging' }

      before(:each) do
        File.open(File.join(hieradata_dir, 'profile-merging.yaml'), 'w') do |fh|
          test_hiera = { 'compliance_engine::enforcement' => %w[profile_test2 profile_test1] }.to_yaml
          fh.puts test_hiera
        end
      end

      # Test a string.
      it { is_expected.to run.with_params('test_module_04::string_param').and_return('string value 2') }

      # Test a simple array.
      it { is_expected.to run.with_params('test_module_04::array_param').and_return(['array value 1', 'array value 2']) }

      # Test a simple hash.
      it { is_expected.to run.with_params('test_module_04::hash_param').and_return({ 'hash key 2' => 'hash value 2', 'hash key 1' => 'hash value 1' }) }

      # Test a nested hash.
      it { is_expected.to run.with_params('test_module_04::nested_hash').and_return({ 'key' => { 'key1' => 'value2', 'key2' => 'value2' } }) }
    end
  end
end
