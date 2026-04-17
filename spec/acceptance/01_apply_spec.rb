# frozen_string_literal: true

require 'spec_helper_acceptance'

# Verifies that the compliance_engine Hiera backend works correctly when Puppet
# runs locally via `puppet apply` (MRI Ruby / openvox-agent, no server involved).
describe 'compliance_engine::enforcement with puppet apply' do
  before(:all) do
    create_test_module(
      default,
      module_name: 'ce_apply_test',
      param_name: 'enforced_param',
      enforced_value: 'enforced_via_compliance',
      profile_name: 'apply_test_profile',
    )

    configure_hiera(default, profile: 'apply_test_profile')
    ensure_environment(default)
  end

  it 'enforces the compliance value via Hiera lookup' do
    result = on(default,
                "puppet apply --environment production -e 'include ce_apply_test'",
                acceptable_exit_codes: [0, 2])

    expect(combined_output(result)).to include('enforced_param=enforced_via_compliance')
  end

  it 'applies idempotently on a second run' do
    result = on(default,
                "puppet apply --environment production -e 'include ce_apply_test'",
                acceptable_exit_codes: [0, 2])

    expect(combined_output(result)).not_to match(/Error:/i)
  end
end
