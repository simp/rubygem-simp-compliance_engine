# frozen_string_literal: true

require 'timeout'
require 'yaml'

require 'rspec'

# spec_helper.rb (auto-required by .rspec) calls disable_monkey_patching!
# which removes shared_examples from main via expose_dsl_globally = false.
# Acceptance tests and beaker-rspec depend on the global DSL, so re-enable it
# before loading voxpupuli-acceptance (which calls shared_examples at the top
# level of examples.rb before beaker-rspec has a chance to set things up).
RSpec.configuration.expose_dsl_globally = true

require 'voxpupuli/acceptance/spec_helper_acceptance'

RSpec.configure do |c|
  # We configure hiera explicitly in each spec; the voxpupuli-acceptance
  # suite_hiera support copies static files, which doesn't fit our dynamic
  # per-test compliance data needs.
  c.suite_hiera = false
end

# configure_beaker installs openvox-agent on every host, then yields each host
# to this block inside before(:suite).  We use the block to layer openvox-server
# on top of the agent package on any host with the 'master' role.
#
# NOTE: voxpupuli-acceptance wraps beaker/beaker-docker and supports multi-node
# setups via a custom nodeset YAML passed as BEAKER_SETFILE.  If we ever need
# lower-level control (e.g. beaker pre/post hooks that voxpupuli-acceptance does
# not expose), the acceptance tasks in the Rakefile can be switched to use
# beaker-rspec/rake_task directly.
configure_beaker(modules: :metadata) do |host|
  next unless host['roles'].include?('master')

  # openvox-agent is already on PATH at this point; add the server package.
  host.install_package('openvox-server')

  # Add the container's short hostname to dns_alt_names BEFORE starting the
  # server so the generated SSL cert includes it as a SAN.  Without this, the
  # server cert only covers the FQDN (e.g. server.example.net) but agents
  # connect using the short hostname that beaker writes to /etc/hosts.
  on(host, "puppet config set --section main dns_alt_names puppet,#{host.hostname}")

  on(host, 'puppet config set --section master autosign true')

  # Service name may differ between OpenVox and upstream Puppet packages.
  on(host, 'systemctl start openvox-server 2>/dev/null || systemctl start puppetserver')

  # Wait up to 120 s for port 8140 to open before proceeding.
  Timeout.timeout(120) do
    loop do
      result = on(host, 'ss -tlnp 2>/dev/null | grep -q :8140 && echo READY || true',
                  accept_all_exit_codes: true)
      break if result.stdout.strip == 'READY'

      sleep 2
    end
  end

  # 'puppet module install' (called by install_local_module_on) installs to the
  # first writable path in the modulepath, which is typically the production
  # environment's module directory.  Copy compliance_engine into the
  # basemodulepath so that every Puppet environment can find it.
  on(host, <<~SH)
    src=$(puppet config print modulepath | tr ':' '\n' | \
          while read dir; do [ -d "$dir/compliance_engine" ] && echo "$dir/compliance_engine" && break; done)
    base=$(puppet config print basemodulepath | tr ':' '\n' | head -1)
    if [ -n "$src" ] && [ "$(dirname "$src")" != "$base" ]; then
      rm -rf "$base/compliance_engine"
      cp -r "$src" "$base/"
    fi
  SH
end

# ---------------------------------------------------------------------------
# Shared helpers included into every acceptance example group.
# ---------------------------------------------------------------------------
module AcceptanceHelpers
  # Absolute path to the codedir on a host (cached per host).
  def codedir(host)
    @codedir ||= {}
    @codedir[host.hostname] ||= on(host, 'puppet config print codedir').stdout.strip
  end

  # Path to a Puppet environment directory on host.
  def env_dir(host, env = 'production')
    "#{codedir(host)}/environments/#{env}"
  end

  # Ensure an environment directory and a minimal (empty) site.pp exist.
  def ensure_environment(host, env = 'production')
    dir = env_dir(host, env)
    on(host, "mkdir -p #{dir}/manifests")
    on(host, "test -f #{dir}/manifests/site.pp || touch #{dir}/manifests/site.pp")
  end

  # Create a minimal Puppet module with one String parameter plus a compliance
  # profile that enforces a specific value for that parameter.
  #
  # @param host           Beaker host on which to create the module
  # @param module_name    Puppet module name (e.g. 'ce_test')
  # @param param_name     Class parameter name (e.g. 'enforced_param')
  # @param enforced_value The value the compliance engine should enforce
  # @param profile_name   Name of the compliance profile
  # @param env            Puppet environment (default: 'production')
  # @param confine        Optional confinement hash written into the check entry
  # @param declare        If true (default), append "include <module_name>" to
  #                       the environment's site.pp so the class enters the catalog
  def create_test_module(host, module_name:, param_name:, enforced_value:,
                         profile_name:, env: 'production', confine: nil, declare: true)
    dir = "#{env_dir(host, env)}/modules/#{module_name}"
    on(host, "mkdir -p #{dir}/manifests #{dir}/SIMP/compliance_profiles")

    # Generate the Puppet class. Ruby interpolates module_name/param_name;
    # the $-prefixed identifiers are Puppet variables and are left as-is.
    create_remote_file(host, "#{dir}/manifests/init.pp", <<~PP)
      class #{module_name} (
        String $#{param_name} = 'default_value',
      ) {
        notify { "${module_name}::#{param_name}=${#{param_name}}": }
      }
    PP

    check_entry = {
      'type' => 'puppet-class-parameter',
      'settings' => {
        'parameter' => "#{module_name}::#{param_name}",
        'value' => enforced_value,
      },
      'ces' => ["#{profile_name}_ce"],
    }
    check_entry['confine'] = confine if confine

    compliance_data = {
      'version' => '2.0.0',
      'profiles' => {
        profile_name => { 'controls' => { "#{profile_name}_ctl" => true } },
      },
      'ce' => {
        "#{profile_name}_ce" => { 'controls' => { "#{profile_name}_ctl" => true } },
      },
      'checks' => { "#{profile_name}_chk" => check_entry },
    }

    create_remote_file(host, "#{dir}/SIMP/compliance_profiles/data.yaml",
                       compliance_data.to_yaml)

    # Ensure the Puppet server process (which runs as the 'puppet' user) can
    # read all files in the module directory.
    on(host, "chmod -R a+rX #{dir}")

    return unless declare

    # Append "include <module_name>" to site.pp (idempotent: skip if already present).
    site_pp = "#{env_dir(host, env)}/manifests/site.pp"
    on(host, "mkdir -p #{env_dir(host, env)}/manifests")
    on(host, "grep -qxF 'include #{module_name}' #{site_pp} 2>/dev/null || echo 'include #{module_name}' >> #{site_pp}")
  end

  # Write hiera.yaml and data/common.yaml for a Puppet environment.
  # The hierarchy includes the compliance_engine::enforcement lookup_key backend.
  # Per-node overrides can be placed in data/nodes/<certname>.yaml.
  def configure_hiera(host, profile:, env: 'production')
    dir = env_dir(host, env)
    on(host, "mkdir -p #{dir}/data/nodes")

    create_remote_file(host, "#{dir}/hiera.yaml", <<~YAML)
      ---
      version: 5
      defaults:
        datadir: data
        data_hash: yaml_data
      hierarchy:
        - name: Per-node
          path: "nodes/%{trusted.certname}.yaml"
        - name: Common
          path: common.yaml
        - name: Compliance Engine
          lookup_key: compliance_engine::enforcement
    YAML

    create_remote_file(host, "#{dir}/data/common.yaml", <<~YAML)
      ---
      compliance_engine::enforcement: '#{profile}'
    YAML

    on(host, "chmod -R a+rX #{dir}/data #{dir}/hiera.yaml")
  end

  # Write a per-node hiera data file on the server for a specific certname.
  # @param data  Ruby Hash; written as YAML
  def set_node_hiera(server, certname:, data:, env: 'production')
    dir = env_dir(server, env)
    on(server, "mkdir -p #{dir}/data/nodes")
    create_remote_file(server, "#{dir}/data/nodes/#{certname}.yaml",
                       data.to_yaml)
  end

  # Point an agent's puppet.conf at the given server hostname.
  def configure_agent(agent, server)
    on(agent, "puppet config set --section agent server #{server.hostname}")
  end

  # Convenience: return combined stdout+stderr from an on() result.
  def combined_output(result)
    [result.stdout, result.stderr].join
  end
end

RSpec.configure do |c|
  c.include AcceptanceHelpers
end
