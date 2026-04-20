# frozen_string_literal: true

require 'spec_helper_acceptance'

# Verifies that the compliance_engine Data object is not cached globally on the
# server across different catalog compilations.
#
# If caching leaks between agents, a ComplianceEngine::Data object initialised
# with first_agent's facts (and its fact-confine-selected checks) would be reused for
# second_agent, causing second_agent to receive first_agent's enforced values instead of its own.
#
# Test design:
#   - Both agents use the same compliance profile.
#   - The compliance data contains two checks, each confined to a different
#     agent's FQDN.  Each check enforces a distinct value for the same parameter.
#   - Expected: first_agent gets value_for_first_agent, second_agent gets value_for_second_agent.
#   - Cache leak: second_agent would get value_for_first_agent (or vice-versa).
describe 'compliance_engine cache leakage between agents' do
  let(:server)       { only_host_with_role(hosts, 'master') }
  let(:first_agent)  { hosts_with_role(hosts, 'agent')[0] }
  let(:second_agent) { hosts_with_role(hosts, 'agent')[1] }

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
        'cache_check_first_agent' => {
          'type' => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'ce_cache_test::enforced_param',
            'value' => 'value_for_first_agent',
          },
          'ces' => ['cache_test_ce'],
          'confine' => { 'networking.fqdn' => fqdn1 },
        },
        'cache_check_second_agent' => {
          'type' => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'ce_cache_test::enforced_param',
            'value' => 'value_for_second_agent',
          },
          'ces' => ['cache_test_ce'],
          'confine' => { 'networking.fqdn' => fqdn2 },
        },
      },
    }

    create_remote_file(srv, "#{dir}/SIMP/compliance_profiles/data.yaml",
                       compliance_data.to_yaml)

    on(srv, "chmod -R a+rX #{dir}")

    configure_hiera(srv, profile: 'cache_test_profile')
    ensure_environment(srv)

    site_pp = "#{env_dir(srv, env)}/manifests/site.pp"
    on(srv, "grep -qxF 'include ce_cache_test' #{site_pp} 2>/dev/null || echo 'include ce_cache_test' >> #{site_pp}")
  end

  it 'first_agent receives the value confined to its own FQDN' do
    result = on(first_agent,
                'puppet agent --test --environment production',
                acceptable_exit_codes: [0, 2])

    expect(combined_output(result)).to include('enforced_param=value_for_first_agent')
    expect(combined_output(result)).not_to include('enforced_param=value_for_second_agent')
  end

  it 'second_agent receives the value confined to its own FQDN' do
    result = on(second_agent,
                'puppet agent --test --environment production',
                acceptable_exit_codes: [0, 2])

    expect(combined_output(result)).to include('enforced_param=value_for_second_agent')
    expect(combined_output(result)).not_to include('enforced_param=value_for_first_agent')
  end

  it 'first_agent still receives its own value after second_agent has run' do
    # Run second_agent first to prime any potential server-side cache.
    on(second_agent, 'puppet agent --test --environment production',
       acceptable_exit_codes: [0, 2])

    result = on(first_agent,
                'puppet agent --test --environment production',
                acceptable_exit_codes: [0, 2])

    expect(combined_output(result)).to include('enforced_param=value_for_first_agent')
    expect(combined_output(result)).not_to include('enforced_param=value_for_second_agent')
  end
end
