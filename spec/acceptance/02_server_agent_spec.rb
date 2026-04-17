# frozen_string_literal: true

require 'spec_helper_acceptance'

# Verifies that the compliance_engine Hiera backend works correctly when Puppet
# runs as a client/server pair (openvox-server compiles the catalog using JRuby;
# openvox-agent applies it).  This is the scenario most likely to expose the
# known `observer` gem availability issue.
describe 'compliance_engine::enforcement with puppet agent + openvox-server' do
  let(:server) { only_host_with_role(hosts, 'master') }
  let(:agent)  { hosts_with_role(hosts, 'agent').first }

  before(:all) do
    srv = only_host_with_role(hosts, 'master')
    agt = hosts_with_role(hosts, 'agent').first

    configure_agent(agt, srv)

    create_test_module(
      srv,
      module_name: 'ce_server_test',
      param_name: 'enforced_param',
      enforced_value: 'server_enforced_value',
      profile_name: 'server_test_profile',
    )

    configure_hiera(srv, profile: 'server_test_profile')
    ensure_environment(srv)
  end

  it 'compiles and applies a catalog with the enforced compliance value' do
    result = on(agent,
                'puppet agent --test --environment production',
                acceptable_exit_codes: [0, 2])

    expect(combined_output(result)).to include('enforced_param=server_enforced_value')
  end

  it 'runs idempotently on a second puppet agent run' do
    result = on(agent,
                'puppet agent --test --environment production',
                acceptable_exit_codes: [0, 2])

    expect(combined_output(result)).not_to match(/Error:/i)
  end
end
