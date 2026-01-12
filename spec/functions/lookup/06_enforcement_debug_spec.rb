#!/usr/bin/env ruby -S rspec
# frozen_string_literal: true

require 'spec_helper'
require 'spec_helper_puppet'
require 'yaml'
require 'fileutils'
require 'tmpdir'

RSpec.describe 'lookup', skip: 'Debug features not yet implemented in compliance_engine' do
  # Generate a fake module with dummy data for lookup().
  let(:profile) do
    {
      'version' => '2.0.0',
      'profiles' => {
        '06_profile_test' => {
          'controls' => {
            '06_control1' => true,
          },
        },
      },
    }
  end

  let(:ces) do
    {
      'version' => '2.0.0',
      'ce' => {
        '06_ce1' => {
          'controls' => {
            '06_control1' => true,
          },
        },
      },
    }
  end

  let(:checks) do
    {
      'version' => '2.0.0',
      'checks' => {
        '06_check1' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_06::test_param',
            'value'     => 'a string',
          },
          'ces' => [
            '06_ce1',
          ],
        },
        '06_check2' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_06::test_param2',
            'value'     => 'another string',
          },
          'ces' => [
            '06_ce1',
          ],
        },
      },
    }
  end

  let(:tmpdir) { Dir.mktmpdir('compliance_engine_test') }
  let(:test_module_path) { File.join(tmpdir, 'test_module_06') }
  let(:compliance_dir) { File.join(test_module_path, 'SIMP', 'compliance_profiles') }

  before(:each) do
    # Create the directory structure
    FileUtils.mkdir_p(compliance_dir)

    # Write the test data files
    File.write(File.join(compliance_dir, 'profiles.yaml'), profile.to_yaml)
    File.write(File.join(compliance_dir, 'ces.yaml'), ces.to_yaml)
    File.write(File.join(compliance_dir, 'checks.yaml'), checks.to_yaml)

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
    context "on #{os} compliance_engine::debug values" do
      let(:lookup) { subject }
      let(:facts) do
        os_facts.merge('target_compliance_profile' => '06_profile_test')
      end

      let(:hieradata) { 'compliance-engine' }

      it do
        result = lookup.execute('compliance_engine::debug::hiera_backend_compile_time')
        expect(result).to be_a(Float)
        expect(result).to be > 0
      end

      it do
        result = lookup.execute('compliance_engine::debug::dump')
        expect(result).to be_a(Hash)
        expect(result['test_module_06::test_param']).to eq('a string')
        expect(result['test_module_06::test_param2']).to eq('another string')
        expect(result.keys).to eq([
                                    'test_module_06::test_param',
                                    'test_module_06::test_param2',
                                    'compliance_engine::debug::hiera_backend_compile_time',
                                  ])
      end

      it do
        result = lookup.execute('compliance_engine::debug::profiles')
        expect(result).to be_a(Array)
        expect(result).to include('06_profile_test')
      end

      it do
        result = lookup.execute('compliance_engine::debug::compliance_data')
        expect(result).to be_a(Hash)
        expect(result.keys).to eq(%w[version profiles ce checks])
        expect(result['profiles']).to include(profile['profiles'])
        expect(result['ce']).to include(ces['ce'])
        expect(result['checks']).to include(checks['checks'])
      end
    end
  end
end
