# frozen_string_literal: true

require 'spec_helper_acceptance'

# Verifies that compliance_engine reflects changes to its data files within a
# Puppet environment between catalog compilations, instead of returning stale
# cached values from a prior compilation.
#
# Test design:
#   - One agent connects to the server in the 'production' environment and
#     applies the same class on every run.
#   - The compliance data backing that class is mutated between agent runs:
#     first modified in place, then deleted entirely.
#   - Expected: each agent run reflects the current on-disk data.
#   - Cache leak: an agent run returns the value from a prior on-disk state.
#
# Note: spec_helper_acceptance sets `environment_timeout = 0` on the master so
# that the puppetserver's own environment cache cannot mask compliance_engine's
# caching behaviour.
describe 'compliance_engine reflects updates to environment data' do
  let(:server) { only_host_with_role(hosts, 'master') }
  let(:agent)  { hosts_with_role(hosts, 'agent').first }

  before(:all) do
    srv = only_host_with_role(hosts, 'master')
    agt = hosts_with_role(hosts, 'agent').first

    configure_agent(agt, srv)

    create_test_module(
      srv,
      module_name: 'ce_update_test',
      param_name: 'enforced_param',
      enforced_value: 'before_value',
      profile_name: 'update_test_profile',
    )

    configure_hiera(srv, profile: 'update_test_profile')
    ensure_environment(srv)
  end

  context 'with the initial compliance data' do
    it 'enforces the original value on the agent' do
      result = on(agent,
                  'puppet agent --test --environment production',
                  acceptable_exit_codes: [0, 2])

      expect(combined_output(result)).to include('enforced_param=before_value')
    end
  end

  context 'after the compliance data file is modified in place' do
    before(:all) do
      srv = only_host_with_role(hosts, 'master')

      create_test_module(
        srv,
        module_name: 'ce_update_test',
        param_name: 'enforced_param',
        enforced_value: 'after_value',
        profile_name: 'update_test_profile',
      )
    end

    it 'enforces the new value on the agent (no stale cache)' do
      result = on(agent,
                  'puppet agent --test --environment production',
                  acceptable_exit_codes: [0, 2])

      expect(combined_output(result)).to include('enforced_param=after_value')
      expect(combined_output(result)).not_to include('enforced_param=before_value')
    end
  end

  context 'after the compliance data file is deleted' do
    before(:all) do
      srv = only_host_with_role(hosts, 'master')
      data_file = "#{env_dir(srv)}/modules/ce_update_test/SIMP/compliance_profiles/data.yaml"
      on(srv, "rm -f #{data_file}")
    end

    it 'falls back to the class default value' do
      result = on(agent,
                  'puppet agent --test --environment production',
                  acceptable_exit_codes: [0, 2])

      expect(combined_output(result)).to include('enforced_param=default_value')
      expect(combined_output(result)).not_to include('enforced_param=after_value')
    end
  end
end
