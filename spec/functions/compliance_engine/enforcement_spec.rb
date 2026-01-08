# frozen_string_literal: true

require 'spec_helper'
require 'spec_helper_puppet'
require 'yaml'
require 'fileutils'
require 'tmpdir'

# Tests for the compliance_engine::enforcement Hiera backend.
# Since this is a lookup_key backend, we test it through the `lookup` function.
#
# These tests create temporary fixture files to test the enforcement backend
# without relying on complex mocking of the file system.
RSpec.describe 'lookup' do
  # Create a temporary directory structure for test modules
  let(:tmpdir) { Dir.mktmpdir('compliance_engine_test') }
  let(:test_module_path) { File.join(tmpdir, 'test_enforcement_module') }
  let(:compliance_dir) { File.join(test_module_path, 'SIMP', 'compliance_profiles') }

  # Default test data - can be overridden in specific contexts
  let(:profile_data) do
    {
      'version' => '2.0.0',
      'profiles' => {
        'enforcement_spec_profile' => {
          'controls' => {
            'enforcement_spec_control' => true,
          },
        },
      },
    }
  end

  let(:ces_data) do
    {
      'version' => '2.0.0',
      'ce' => {
        'enforcement_spec_ce' => {
          'controls' => {
            'enforcement_spec_control' => true,
          },
        },
      },
    }
  end

  let(:checks_data) do
    {
      'version' => '2.0.0',
      'checks' => {
        'enforcement_spec_check' => {
          'type' => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'enforcement_spec::test_param',
            'value' => 'test_enforced_value',
          },
          'ces' => [
            'enforcement_spec_ce',
          ],
        },
        'enforcement_spec_check2' => {
          'type' => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'enforcement_spec::another_param',
            'value' => 42,
          },
          'ces' => [
            'enforcement_spec_ce',
          ],
        },
      },
    }
  end

  before(:each) do
    # Create the directory structure
    FileUtils.mkdir_p(compliance_dir)

    # Write the test data files
    File.write(File.join(compliance_dir, 'profiles.yaml'), profile_data.to_yaml)
    File.write(File.join(compliance_dir, 'ces.yaml'), ces_data.to_yaml)
    File.write(File.join(compliance_dir, 'checks.yaml'), checks_data.to_yaml)

    # Mock the Puppet environment's modulepath to include our temp directory
    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(Puppet::Node::Environment).to receive(:full_modulepath).and_return([tmpdir])
    # rubocop:enable RSpec/AnyInstance
  end

  after(:each) do
    # Clean up temporary directory
    FileUtils.rm_rf(tmpdir)
  end

  context 'with compliance_engine::enforcement backend and no profile configured' do
    let(:hieradata) { 'common' }
    let(:facts) { {} }

    it 'returns not_found for any key when no profiles are set' do
      is_expected.to run.with_params('enforcement_spec::test_param')
                        .and_raise_error(Puppet::DataBinding::LookupError, %r{did not find a value})
    end
  end

  context 'with compliance_engine::enforcement backend and a valid profile' do
    let(:facts) do
      { 'target_compliance_profile' => 'enforcement_spec_profile' }
    end
    let(:hieradata) { 'compliance-engine' }

    it 'returns the enforced string value for a matching parameter' do
      is_expected.to run.with_params('enforcement_spec::test_param').and_return('test_enforced_value')
    end

    it 'returns the enforced integer value for a matching parameter' do
      is_expected.to run.with_params('enforcement_spec::another_param').and_return(42)
    end

    it 'returns not_found for keys not in compliance data' do
      is_expected.to run.with_params('unknown::param')
                        .and_raise_error(Puppet::DataBinding::LookupError, %r{did not find a value})
    end

    it 'returns not_found for lookup_options key' do
      is_expected.to run.with_params('lookup_options')
                        .and_raise_error(Puppet::DataBinding::LookupError, %r{did not find a value})
    end

    it 'returns not_found for compliance_engine:: prefixed keys' do
      is_expected.to run.with_params('compliance_engine::some_internal_key')
                        .and_raise_error(Puppet::DataBinding::LookupError, %r{did not find a value})
    end

    it 'returns not_found for compliance_markup:: prefixed keys' do
      is_expected.to run.with_params('compliance_markup::some_internal_key')
                        .and_raise_error(Puppet::DataBinding::LookupError, %r{did not find a value})
    end
  end

  context 'with compliance_engine::enforcement backend and a non-existent profile' do
    let(:facts) do
      { 'target_compliance_profile' => 'nonexistent_profile' }
    end
    let(:hieradata) { 'compliance-engine' }

    it 'returns not_found when the profile does not exist' do
      is_expected.to run.with_params('enforcement_spec::test_param')
                        .and_raise_error(Puppet::DataBinding::LookupError, %r{did not find a value})
    end
  end

  context 'with multiple profiles configured' do
    let(:profile_data) do
      {
        'version' => '2.0.0',
        'profiles' => {
          'profile_one' => {
            'controls' => {
              'control_one' => true,
            },
          },
          'profile_two' => {
            'controls' => {
              'control_two' => true,
            },
          },
        },
      }
    end

    let(:ces_data) do
      {
        'version' => '2.0.0',
        'ce' => {
          'ce_one' => {
            'controls' => {
              'control_one' => true,
            },
          },
          'ce_two' => {
            'controls' => {
              'control_two' => true,
            },
          },
        },
      }
    end

    let(:checks_data) do
      {
        'version' => '2.0.0',
        'checks' => {
          'check_from_profile_one' => {
            'type' => 'puppet-class-parameter',
            'settings' => {
              'parameter' => 'multi_profile::param_one',
              'value' => 'value_from_profile_one',
            },
            'ces' => ['ce_one'],
          },
          'check_from_profile_two' => {
            'type' => 'puppet-class-parameter',
            'settings' => {
              'parameter' => 'multi_profile::param_two',
              'value' => 'value_from_profile_two',
            },
            'ces' => ['ce_two'],
          },
        },
      }
    end

    let(:facts) do
      { 'target_compliance_profile' => 'profile_one' }
    end
    let(:hieradata) { 'compliance-engine' }

    it 'returns value from the first profile' do
      is_expected.to run.with_params('multi_profile::param_one').and_return('value_from_profile_one')
    end

    it 'returns not_found for value only in second profile when first profile is selected' do
      is_expected.to run.with_params('multi_profile::param_two')
                        .and_raise_error(Puppet::DataBinding::LookupError, %r{did not find a value})
    end
  end

  context 'with fact-based confine on checks' do
    let(:profile_data) do
      {
        'version' => '2.0.0',
        'profiles' => {
          'confine_test_profile' => {
            'controls' => {
              'confine_control' => true,
            },
          },
        },
      }
    end

    let(:ces_data) do
      {
        'version' => '2.0.0',
        'ce' => {
          'confine_ce' => {
            'controls' => {
              'confine_control' => true,
            },
          },
        },
      }
    end

    let(:checks_data) do
      {
        'version' => '2.0.0',
        'checks' => {
          'redhat_only_check' => {
            'type' => 'puppet-class-parameter',
            'settings' => {
              'parameter' => 'confine_test::redhat_param',
              'value' => 'redhat_value',
            },
            'ces' => ['confine_ce'],
            'confine' => {
              'os.family' => 'RedHat',
            },
          },
          'debian_only_check' => {
            'type' => 'puppet-class-parameter',
            'settings' => {
              'parameter' => 'confine_test::debian_param',
              'value' => 'debian_value',
            },
            'ces' => ['confine_ce'],
            'confine' => {
              'os.family' => 'Debian',
            },
          },
          'any_os_check' => {
            'type' => 'puppet-class-parameter',
            'settings' => {
              'parameter' => 'confine_test::any_os_param',
              'value' => 'any_os_value',
            },
            'ces' => ['confine_ce'],
          },
        },
      }
    end

    let(:hieradata) { 'compliance-engine' }

    context 'on RedHat family' do
      let(:facts) do
        {
          'target_compliance_profile' => 'confine_test_profile',
          'os' => { 'family' => 'RedHat' },
        }
      end

      it 'returns value for RedHat-confined check' do
        is_expected.to run.with_params('confine_test::redhat_param').and_return('redhat_value')
      end

      it 'returns not_found for Debian-confined check' do
        is_expected.to run.with_params('confine_test::debian_param')
                          .and_raise_error(Puppet::DataBinding::LookupError, %r{did not find a value})
      end

      it 'returns value for non-confined check' do
        is_expected.to run.with_params('confine_test::any_os_param').and_return('any_os_value')
      end
    end

    context 'on Debian family' do
      let(:facts) do
        {
          'target_compliance_profile' => 'confine_test_profile',
          'os' => { 'family' => 'Debian' },
        }
      end

      it 'returns not_found for RedHat-confined check' do
        is_expected.to run.with_params('confine_test::redhat_param')
                          .and_raise_error(Puppet::DataBinding::LookupError, %r{did not find a value})
      end

      it 'returns value for Debian-confined check' do
        is_expected.to run.with_params('confine_test::debian_param').and_return('debian_value')
      end

      it 'returns value for non-confined check' do
        is_expected.to run.with_params('confine_test::any_os_param').and_return('any_os_value')
      end
    end
  end

  context 'with disabled remediation on checks' do
    let(:profile_data) do
      {
        'version' => '2.0.0',
        'profiles' => {
          'remediation_test_profile' => {
            'controls' => {
              'remediation_control' => true,
            },
          },
        },
      }
    end

    let(:ces_data) do
      {
        'version' => '2.0.0',
        'ce' => {
          'remediation_ce' => {
            'controls' => {
              'remediation_control' => true,
            },
          },
        },
      }
    end

    let(:checks_data) do
      {
        'version' => '2.0.0',
        'checks' => {
          'enabled_check' => {
            'type' => 'puppet-class-parameter',
            'settings' => {
              'parameter' => 'remediation_test::enabled_param',
              'value' => 'enabled_value',
            },
            'ces' => ['remediation_ce'],
          },
          'disabled_check' => {
            'type' => 'puppet-class-parameter',
            'settings' => {
              'parameter' => 'remediation_test::disabled_param',
              'value' => 'disabled_value',
            },
            'ces' => ['remediation_ce'],
            'remediation' => {
              'disabled' => [
                { 'reason' => 'This check is disabled for testing.' },
              ],
            },
          },
        },
      }
    end

    let(:facts) do
      { 'target_compliance_profile' => 'remediation_test_profile' }
    end
    let(:hieradata) { 'compliance-engine' }

    it 'returns value for enabled check' do
      is_expected.to run.with_params('remediation_test::enabled_param').and_return('enabled_value')
    end

    # NOTE: Disabled checks are still returned by default - they are informational
    # and filtering them requires explicit configuration
    it 'still returns value for disabled check (disabled is informational only)' do
      is_expected.to run.with_params('remediation_test::disabled_param').and_return('disabled_value')
    end
  end

  context 'with risk-level remediation and enforcement tolerance' do
    let(:profile_data) do
      {
        'version' => '2.0.0',
        'profiles' => {
          'tolerance_test_profile' => {
            'controls' => {
              'tolerance_control' => true,
            },
          },
        },
      }
    end

    let(:ces_data) do
      {
        'version' => '2.0.0',
        'ce' => {
          'tolerance_ce' => {
            'controls' => {
              'tolerance_control' => true,
            },
          },
        },
      }
    end

    let(:checks_data) do
      {
        'version' => '2.0.0',
        'checks' => {
          'no_risk_check' => {
            'type' => 'puppet-class-parameter',
            'settings' => {
              'parameter' => 'tolerance_test::no_risk_param',
              'value' => 'no_risk_value',
            },
            'ces' => ['tolerance_ce'],
          },
          'low_risk_check' => {
            'type' => 'puppet-class-parameter',
            'settings' => {
              'parameter' => 'tolerance_test::low_risk_param',
              'value' => 'low_risk_value',
            },
            'ces' => ['tolerance_ce'],
            'remediation' => {
              'risk' => [
                { 'level' => 20, 'reason' => 'Low risk check' },
              ],
            },
          },
          'medium_risk_check' => {
            'type' => 'puppet-class-parameter',
            'settings' => {
              'parameter' => 'tolerance_test::medium_risk_param',
              'value' => 'medium_risk_value',
            },
            'ces' => ['tolerance_ce'],
            'remediation' => {
              'risk' => [
                { 'level' => 50, 'reason' => 'Medium risk check' },
              ],
            },
          },
          'high_risk_check' => {
            'type' => 'puppet-class-parameter',
            'settings' => {
              'parameter' => 'tolerance_test::high_risk_param',
              'value' => 'high_risk_value',
            },
            'ces' => ['tolerance_ce'],
            'remediation' => {
              'risk' => [
                { 'level' => 80, 'reason' => 'High risk check' },
              ],
            },
          },
        },
      }
    end

    # NOTE: When no enforcement tolerance is set (nil), all risk levels are accepted
    context 'with no enforcement tolerance set (default accepts all)' do
      let(:facts) do
        { 'target_compliance_profile' => 'tolerance_test_profile' }
      end
      let(:hieradata) { 'compliance-engine' }

      it 'returns value for no-risk check' do
        is_expected.to run.with_params('tolerance_test::no_risk_param').and_return('no_risk_value')
      end

      it 'returns value for low-risk check (no filtering when tolerance is nil)' do
        is_expected.to run.with_params('tolerance_test::low_risk_param').and_return('low_risk_value')
      end

      it 'returns value for medium-risk check (no filtering when tolerance is nil)' do
        is_expected.to run.with_params('tolerance_test::medium_risk_param').and_return('medium_risk_value')
      end

      it 'returns value for high-risk check (no filtering when tolerance is nil)' do
        is_expected.to run.with_params('tolerance_test::high_risk_param').and_return('high_risk_value')
      end
    end

    # Use dedicated hieradata file with hardcoded integer tolerance
    # (Hiera interpolation from facts would produce a string, but the code requires Integer)
    context 'with enforcement tolerance set to 25' do
      let(:facts) do
        {
          'target_compliance_profile' => 'tolerance_test_profile',
          'custom_hiera' => 'compliance_engine-tolerance-25',
        }
      end
      let(:hieradata) { 'compliance_engine-tolerance-25' }

      it 'returns value for no-risk check' do
        is_expected.to run.with_params('tolerance_test::no_risk_param').and_return('no_risk_value')
      end

      it 'returns value for low-risk check (level 20 < tolerance 25)' do
        is_expected.to run.with_params('tolerance_test::low_risk_param').and_return('low_risk_value')
      end

      it 'returns not_found for medium-risk check (level 50 >= tolerance 25)' do
        is_expected.to run.with_params('tolerance_test::medium_risk_param')
                          .and_raise_error(Puppet::DataBinding::LookupError, %r{did not find a value})
      end

      it 'returns not_found for high-risk check (level 80 >= tolerance 25)' do
        is_expected.to run.with_params('tolerance_test::high_risk_param')
                          .and_raise_error(Puppet::DataBinding::LookupError, %r{did not find a value})
      end
    end

    context 'with enforcement tolerance set to 60' do
      let(:facts) do
        {
          'target_compliance_profile' => 'tolerance_test_profile',
          'custom_hiera' => 'compliance_engine-tolerance-60',
        }
      end
      let(:hieradata) { 'compliance_engine-tolerance-60' }

      it 'returns value for no-risk check' do
        is_expected.to run.with_params('tolerance_test::no_risk_param').and_return('no_risk_value')
      end

      it 'returns value for low-risk check' do
        is_expected.to run.with_params('tolerance_test::low_risk_param').and_return('low_risk_value')
      end

      it 'returns value for medium-risk check (level 50 < tolerance 60)' do
        is_expected.to run.with_params('tolerance_test::medium_risk_param').and_return('medium_risk_value')
      end

      it 'returns not_found for high-risk check (level 80 >= tolerance 60)' do
        is_expected.to run.with_params('tolerance_test::high_risk_param')
                          .and_raise_error(Puppet::DataBinding::LookupError, %r{did not find a value})
      end
    end

    context 'with enforcement tolerance set to 100' do
      let(:facts) do
        {
          'target_compliance_profile' => 'tolerance_test_profile',
          'custom_hiera' => 'compliance_engine-tolerance-100',
        }
      end
      let(:hieradata) { 'compliance_engine-tolerance-100' }

      it 'returns value for all checks including high-risk' do
        is_expected.to run.with_params('tolerance_test::high_risk_param').and_return('high_risk_value')
      end
    end
  end

  context 'with different value types' do
    let(:profile_data) do
      {
        'version' => '2.0.0',
        'profiles' => {
          'types_test_profile' => {
            'controls' => {
              'types_control' => true,
            },
          },
        },
      }
    end

    let(:ces_data) do
      {
        'version' => '2.0.0',
        'ce' => {
          'types_ce' => {
            'controls' => {
              'types_control' => true,
            },
          },
        },
      }
    end

    let(:checks_data) do
      {
        'version' => '2.0.0',
        'checks' => {
          'string_check' => {
            'type' => 'puppet-class-parameter',
            'settings' => {
              'parameter' => 'types_test::string_param',
              'value' => 'a string value',
            },
            'ces' => ['types_ce'],
          },
          'integer_check' => {
            'type' => 'puppet-class-parameter',
            'settings' => {
              'parameter' => 'types_test::integer_param',
              'value' => 42,
            },
            'ces' => ['types_ce'],
          },
          'boolean_true_check' => {
            'type' => 'puppet-class-parameter',
            'settings' => {
              'parameter' => 'types_test::bool_true_param',
              'value' => true,
            },
            'ces' => ['types_ce'],
          },
          'boolean_false_check' => {
            'type' => 'puppet-class-parameter',
            'settings' => {
              'parameter' => 'types_test::bool_false_param',
              'value' => false,
            },
            'ces' => ['types_ce'],
          },
          'array_check' => {
            'type' => 'puppet-class-parameter',
            'settings' => {
              'parameter' => 'types_test::array_param',
              'value' => ['item1', 'item2', 'item3'],
            },
            'ces' => ['types_ce'],
          },
          'hash_check' => {
            'type' => 'puppet-class-parameter',
            'settings' => {
              'parameter' => 'types_test::hash_param',
              'value' => { 'key1' => 'value1', 'key2' => 'value2' },
            },
            'ces' => ['types_ce'],
          },
        },
      }
    end

    let(:facts) do
      { 'target_compliance_profile' => 'types_test_profile' }
    end
    let(:hieradata) { 'compliance-engine' }

    it 'returns string value' do
      is_expected.to run.with_params('types_test::string_param').and_return('a string value')
    end

    it 'returns integer value' do
      is_expected.to run.with_params('types_test::integer_param').and_return(42)
    end

    it 'returns boolean true value' do
      is_expected.to run.with_params('types_test::bool_true_param').and_return(true)
    end

    it 'returns boolean false value' do
      is_expected.to run.with_params('types_test::bool_false_param').and_return(false)
    end

    it 'returns array value' do
      is_expected.to run.with_params('types_test::array_param').and_return(['item1', 'item2', 'item3'])
    end

    it 'returns hash value' do
      is_expected.to run.with_params('types_test::hash_param').and_return({ 'key1' => 'value1', 'key2' => 'value2' })
    end
  end

  context 'with controls referenced directly in profile' do
    let(:profile_data) do
      {
        'version' => '2.0.0',
        'profiles' => {
          'direct_control_profile' => {
            'controls' => {
              'direct_control' => true,
            },
          },
        },
      }
    end

    let(:ces_data) do
      {
        'version' => '2.0.0',
        'ce' => {
          'direct_ce' => {
            'controls' => {
              'direct_control' => true,
            },
          },
        },
      }
    end

    let(:checks_data) do
      {
        'version' => '2.0.0',
        'checks' => {
          'direct_check' => {
            'type' => 'puppet-class-parameter',
            'settings' => {
              'parameter' => 'direct_test::param',
              'value' => 'direct_value',
            },
            'ces' => ['direct_ce'],
          },
        },
      }
    end

    let(:facts) do
      { 'target_compliance_profile' => 'direct_control_profile' }
    end
    let(:hieradata) { 'compliance-engine' }

    it 'returns value for check linked through control -> ce -> check' do
      is_expected.to run.with_params('direct_test::param').and_return('direct_value')
    end
  end
end
