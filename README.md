# ComplianceEngine

Work with [Sicura](https://sicura.us/) (formerly [SIMP](https://simp-project.com/)) Compliance Engine data.

For more information on the Compliance Engine data format and how to use it, see [the SCE documentation](https://simp-project.com/docs/sce/).

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add compliance_engine

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install compliance_engine

## Usage

### CLI

`compliance_engine` provides a CLI for interacting with Compliance Engine data.

```
Commands:
  compliance_engine dump                                # Dump all compliance data
  compliance_engine help [COMMAND]                      # Describe available commands or one specific command
  compliance_engine hiera --profile=one two three       # Dump Hiera data
  compliance_engine inspect                             # Start an interactive shell
  compliance_engine lookup KEY --profile=one two three  # Look up a Hiera key
  compliance_engine profiles                            # List available profiles
  compliance_engine version                             # Print the version

Options:
  [--facts=FACTS]
  [--enforcement-tolerance=N]
  [--module=one two three]
  [--modulepath=one two three]
  [--modulezip=MODULEZIP]
```

### Library

See the [`ComplianceEngine::Data`](https://rubydoc.info/gems/compliance_engine/ComplianceEngine/Data) class for details.

## Concepts

### Data Model

Compliance data is expressed across four entity types that live in YAML/JSON files inside Puppet modules (`<module>/SIMP/compliance_profiles/*.yaml`):

| Entity | Key | Purpose |
|--------|-----|---------|
| **Profile** | `profiles` | A named compliance standard (e.g. `nist_800_53_rev4`). References CEs, checks, and/or controls that together constitute that standard. |
| **CE** (Compliance Element) | `ce` | A single, named compliance capability (e.g. "enable audit logging"). Bridges profiles to checks via a shared vocabulary. |
| **Check** | `checks` | A verifiable assertion about a system setting. Checks of `type: puppet-class-parameter` carry a `parameter` and `value` that become Hiera data. |
| **Control** | `controls` | A cross-reference label from an external framework (e.g. `nist_800_53:rev4:AU-2`). Profiles and checks both annotate themselves with controls to express alignment. |

### From Profiles to Hiera Data

The central operation of the library is `Data#hiera(profiles)`, which converts a list of profile names into a flat hash of Puppet class parameters and their enforced values:

```
profile names
    ↓  check_mapping: find all checks that belong to each profile
checks (type: puppet-class-parameter only)
    ↓  Check#hiera: extract { 'class::param' => value }
deep-merged hash  →  { 'widget_spinner::audit_logging' => true, ... }
```

**How check_mapping works** — a check is considered part of a profile if any of the following are true:

1. The check and profile share a **control** label (`nist_800_53:rev4:AU-2`).
2. The check and profile share a **CE** reference.
3. The check's CE and the profile share a **control** label.
4. The profile explicitly lists the check by key under its `checks:` map.

This layered matching lets compliance authors express mappings at different levels of abstraction and have the engine resolve them automatically.

### Confinement

A component (profile, CE, check, or control) may be defined across multiple source files. Each file contributes a **fragment**. Before fragments are merged, they are filtered by:

- **Facts** (`confine:` key): dot-notation Puppet facts, optionally negated with a `!` prefix. A fragment is dropped if its confinement does not match the current system's facts.
- **Module presence/version** (`confine.module_name` / `confine.module_version`): fragment is dropped if the required module is absent or the wrong version.
- **Remediation risk** (`remediation.risk`): fragment is dropped if its risk level is ≥ `enforcement_tolerance`, or if remediation is explicitly `disabled`.

If `facts` is `nil`, all fact/module confinement is skipped and every fragment is included.

### Enforcement Tolerance

`enforcement_tolerance` is an integer threshold that controls how cautiously the engine applies remediations. Fragments whose `remediation.risk.level` meets or exceeds the threshold are silently excluded from the merged result, allowing operators to tune aggressiveness (e.g. apply only low-risk remediations in production, all remediations in a test environment).

## Using as a Puppet Module

The Compliance Engine can be used as a Puppet module to provide a Hiera backend for compliance data. This allows you to enforce compliance profiles through Hiera lookups within your Puppet manifests.

### Hiera Backend

To use the Compliance Engine Hiera backend, configure it in your `hiera.yaml`:

```yaml
---
version: 5
hierarchy:
  - name: "Compliance Engine"
    lookup_key: compliance_engine::enforcement
```

Specify the profile used by setting the `compliance_engine::enforcement` key in your Hiera data.

```yaml
---
compliance_engine::enforcement:
  - your_profile
```

The `compliance_engine::enforcement` function serves as the Hiera entry point and allows you to look up compliance data based on configured profiles.

For detailed information about available functions, parameters, and configuration options, see [REFERENCE.md](REFERENCE.md).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/simp/rubygem-simp-compliance_engine.
