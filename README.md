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
