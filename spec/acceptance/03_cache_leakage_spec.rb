# frozen_string_literal: true

require 'spec_helper_acceptance'

# Verifies that the compliance_engine Data object is not cached globally on the
# server across different catalog compilations.
#
# If caching leaks between agents, a ComplianceEngine::Data object initialised
# with agent1's facts (and its fact-confine-selected checks) would be reused for
# agent2, causing agent2 to receive agent1's enforced values instead of its own.
#
# Test design:
#   - Both agents use the same compliance profile.
#   - The compliance data contains two checks, each confined to a different
#     agent's FQDN.  Each check enforces a distinct value for the same parameter.
#   - Expected: agent1 gets value_for_agent1, agent2 gets value_for_agent2.
#   - Cache leak: agent2 would get value_for_agent1 (or vice-versa).
describe 'compliance_engine cache leakage between agents' do
  let(:server) { only_host_with_role(hosts, 'master') }
  let(:agent1) { hosts_with_role(hosts, 'agent')[0] }
  let(:agent2) { hosts_with_role(hosts, 'agent')[1] }

  before(:all) do
    srv = only_host_with_role(hosts, 'master')
    ag1 = hosts_with_role(hosts, 'agent')[0]
    ag2 = hosts_with_role(hosts, 'agent')[1]

    configure_agent(ag1, srv)
    configure_agent(ag2, srv)

    # Discover each agent's FQDN so we can write fact-confined compliance data.
    fqdn1 = fact_on(ag1, 'networking.fqdn')
    fqdn2 = fact_on(ag2, 'networking.fqdn')

    env = 'production'
    dir = "#{env_dir(srv, env)}/modules/ce_cache_test"
    on(srv, "mkdir -p #{dir}/manifests #{dir}/SIMP/compliance_profiles")

    create_remote_file(srv, "#{dir}/manifests/init.pp", <<~PP)
      class ce_cache_test (
        String $enforced_param = 'default_value',
      ) {
        notify { "${module_name}::enforced_param=${enforced_param}": }
      }
    PP

    # One profile; two checks each confined to a different agent's FQDN.
    compliance_data = {
      'version' => '2.0.0',
      'profiles' => {
        'cache_test_profile' => { 'controls' => { 'cache_test_ctl' => true } },
      },
      'ce' => {
        'cache_test_ce' => { 'controls' => { 'cache_test_ctl' => true } },
      },
      'checks' => {
        'cache_check_agent1' => {
          'type' => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'ce_cache_test::enforced_param',
            'value' => 'value_for_agent1',
          },
          'ces' => ['cache_test_ce'],
          'confine' => { 'networking.fqdn' => fqdn1 },
        },
        'cache_check_agent2' => {
          'type' => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'ce_cache_test::enforced_param',
            'value' => 'value_for_agent2',
          },
          'ces' => ['cache_test_ce'],
          'confine' => { 'networking.fqdn' => fqdn2 },
        },
      },
    }

    create_remote_file(srv, "#{dir}/SIMP/compliance_profiles/data.yaml",
                       compliance_data.to_yaml)

    configure_hiera(srv, profile: 'cache_test_profile')
    ensure_environment(srv)
  end

  it 'agent1 receives the value confined to its own FQDN' do
    result = on(agent1,
                'puppet agent --test --environment production',
                acceptable_exit_codes: [0, 2])

    expect(combined_output(result)).to include('enforced_param=value_for_agent1')
    expect(combined_output(result)).not_to include('enforced_param=value_for_agent2')
  end

  it 'agent2 receives the value confined to its own FQDN' do
    result = on(agent2,
                'puppet agent --test --environment production',
                acceptable_exit_codes: [0, 2])

    expect(combined_output(result)).to include('enforced_param=value_for_agent2')
    expect(combined_output(result)).not_to include('enforced_param=value_for_agent1')
  end

  it 'agent1 still receives its own value after agent2 has run' do
    # Run agent2 first to prime any potential server-side cache.
    on(agent2, 'puppet agent --test --environment production',
       acceptable_exit_codes: [0, 2])

    result = on(agent1,
                'puppet agent --test --environment production',
                acceptable_exit_codes: [0, 2])

    expect(combined_output(result)).to include('enforced_param=value_for_agent1')
    expect(combined_output(result)).not_to include('enforced_param=value_for_agent2')
  end
end
