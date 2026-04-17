# frozen_string_literal: true

require 'spec_helper_acceptance'

# Verifies that the compliance_engine Data object is not shared across different
# Puppet environments on the same server.
#
# If the server-side cache leaks across environments, an agent in 'staging'
# could receive compliance values from the 'production' environment (or vice-
# versa).
#
# Test design:
#   - agent1 uses the 'production' environment; enforces value 'production_value'.
#   - agent2 uses the 'staging' environment; enforces value 'staging_value'.
#   - Expected: each agent gets its own environment's value.
#   - Environment leak: an agent gets the other environment's value.
describe 'compliance_engine environment leakage between Puppet environments' do
  let(:server) { only_host_with_role(hosts, 'master') }
  let(:agent1) { hosts_with_role(hosts, 'agent')[0] }
  let(:agent2) { hosts_with_role(hosts, 'agent')[1] }

  before(:all) do
    srv = only_host_with_role(hosts, 'master')
    ag1 = hosts_with_role(hosts, 'agent')[0]
    ag2 = hosts_with_role(hosts, 'agent')[1]

    configure_agent(ag1, srv)
    configure_agent(ag2, srv)

    # Point each agent at its own environment via puppet.conf.
    on(ag1, 'puppet config set --section agent environment production')
    on(ag2, 'puppet config set --section agent environment staging')

    # Set up the 'production' environment.
    create_test_module(
      srv,
      module_name: 'ce_env_test',
      param_name: 'enforced_param',
      enforced_value: 'production_value',
      profile_name: 'env_test_profile',
      env: 'production',
    )
    configure_hiera(srv, profile: 'env_test_profile', env: 'production')
    ensure_environment(srv, 'production')

    # Set up the 'staging' environment (same module name, different enforced value).
    create_test_module(
      srv,
      module_name: 'ce_env_test',
      param_name: 'enforced_param',
      enforced_value: 'staging_value',
      profile_name: 'env_test_profile',
      env: 'staging',
    )
    configure_hiera(srv, profile: 'env_test_profile', env: 'staging')
    ensure_environment(srv, 'staging')
  end

  it 'agent1 (production) receives the production-environment value' do
    result = on(agent1,
                'puppet agent --test',
                acceptable_exit_codes: [0, 2])

    expect(combined_output(result)).to include('enforced_param=production_value')
    expect(combined_output(result)).not_to include('enforced_param=staging_value')
  end

  it 'agent2 (staging) receives the staging-environment value' do
    result = on(agent2,
                'puppet agent --test',
                acceptable_exit_codes: [0, 2])

    expect(combined_output(result)).to include('enforced_param=staging_value')
    expect(combined_output(result)).not_to include('enforced_param=production_value')
  end

  it 'agent1 still receives the production value after agent2 (staging) has run' do
    # Run the staging agent first to prime any potential cross-environment cache.
    on(agent2, 'puppet agent --test', acceptable_exit_codes: [0, 2])

    result = on(agent1,
                'puppet agent --test',
                acceptable_exit_codes: [0, 2])

    expect(combined_output(result)).to include('enforced_param=production_value')
    expect(combined_output(result)).not_to include('enforced_param=staging_value')
  end
end
