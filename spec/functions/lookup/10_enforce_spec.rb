# frozen_string_literal: true

require 'spec_helper'
require 'spec_helper_puppet'
require 'fileutils'
require 'tmpdir'

RSpec.describe 'lookup' do
  let(:tmpdir) { Dir.mktmpdir('compliance_engine_test') }
  let(:hieradata_dir) { File.expand_path('../../data', __dir__) }
  let(:hieradata_file) { "10_enforce_spec-#{Process.pid}" }

  def write_hieradata(hieradata_dir, hieradata_file, policy_order)
    data = {
      'compliance_engine::enforcement'    => policy_order,
      'compliance_engine::compliance_map' => {
        'version' => '2.0.0',
        'profiles' => {
          'disa_stig' => {
            'controls' => {
              'disa_stig' => true,
            },
          },
          'nist_800_53:rev4' => {
            'controls' => {
              'nist_800_53:rev4' => true,
            },
          },
        },
        'controls' => {
          'disa_stig' => {},
          'nist_800_53:rev4' => {},
        },
        'checks' => {
          'oval:com.puppet.test.disa.useradd_shells' => {
            'type'        => 'puppet-class-parameter',
            'controls'    => {
              'disa_stig' => true,
            },
            'identifiers' => {
              'FOO2' => ['FOO2'],
              'BAR2' => ['BAR2']
            },
            'settings'    => {
              'parameter' => 'useradd::shells',
              'value'     => ['/bin/disa']
            }
          },
          'oval:com.puppet.test.nist.useradd_shells' => {
            'type'        => 'puppet-class-parameter',
            'controls'    => {
              'nist_800_53:rev4' => true
            },
            'identifiers' => {
              'FOO2' => ['FOO2'],
              'BAR2' => ['BAR2']
            },
            'settings'    => {
              'parameter' => 'useradd::shells',
              'value'     => ['/bin/nist']
            }
          }
        }
      }
    }

    File.open(File.join(hieradata_dir, "#{hieradata_file}.yaml"), 'w') do |fh|
      fh.puts data.to_yaml
    end
  end

  after(:each) do
    # Clean up temporary directory and hieradata file
    FileUtils.rm_rf(tmpdir)
    FileUtils.rm_f(File.join(hieradata_dir, "#{hieradata_file}.yaml"))
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts.merge('custom_hiera' => hieradata_file) }

      context 'with a single compliance map' do
        let(:lookup) { subject }
        let(:hieradata) { hieradata_file }
        let(:policy_order) { ['disa_stig'] }

        before(:each) do
          write_hieradata(hieradata_dir, hieradata_file, policy_order)
        end

        it 'returns /bin/disa' do
          result = lookup.execute('useradd::shells')
          expect(result).to be_instance_of(Array)
          expect(result).to include('/bin/disa')
        end

        context 'with a String compliance map' do
          let(:policy_order) { 'disa_stig' }

          it 'returns /bin/disa' do
            skip('String value for compliance_engine::enforcement not supported, must be Array')
            result = lookup.execute('useradd::shells')
            expect(result).to be_instance_of(Array)
            expect(result).to include('/bin/disa')
          end
        end
      end

      context 'when disa is higher priority' do
        let(:lookup) { subject }
        let(:hieradata) { hieradata_file }
        let(:policy_order) { ['disa_stig', 'nist_800_53:rev4'] }

        before(:each) do
          write_hieradata(hieradata_dir, hieradata_file, policy_order)
        end

        it 'returns /bin/disa and /bin/nist' do
          result = lookup.execute('useradd::shells')
          expect(result).to be_instance_of(Array)
          expect(result).to include('/bin/disa')
          expect(result).to include('/bin/nist')
        end
      end
    end
  end
end
