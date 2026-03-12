# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## Overview

This is a Ruby gem (`compliance_engine`) that parses and works with [Sicura/SIMP Compliance Engine (SCE)](https://simp-project.com/docs/sce/) data. It also ships as a Puppet module providing a Hiera backend (`compliance_engine::enforcement`) for enforcing compliance profiles in Puppet environments.

## Commands

### Testing
```bash
# Run all tests and rubocop (default task)
bundle exec rake

# Run just spec tests (with fixture prep/cleanup)
bundle exec rake spec

# Run spec tests standalone (no fixture prep)
bundle exec rake spec:standalone

# Run rubocop linting
bundle exec rake rubocop

# Run a single spec file
bundle exec rspec spec/classes/compliance_engine/data_spec.rb

# Run tests in parallel (used in CI for Ruby < 4.0)
bundle exec rake parallel_spec
```

### Development
```bash
# Install dependencies
bundle install

# Open interactive shell with compliance data loaded
bundle exec compliance_engine inspect --module /path/to/module

# CLI usage examples
bundle exec compliance_engine profiles --modulepath /path/to/modules
bundle exec compliance_engine hiera --profile my_profile --modulepath /path/to/modules
bundle exec compliance_engine lookup some::class::param --profile my_profile --module /path/to/module
```

## Architecture

### Data Model

Compliance data lives in YAML/JSON files at `<module>/SIMP/compliance_profiles/*.yaml` or `<module>/simp/compliance_profiles/*.yaml`. Files are structured with four top-level keys: `profiles`, `ce` (Compliance Elements), `checks`, and `controls`.

The library models this data with a two-layer class hierarchy:

**Collections** (`ComplianceEngine::Collection` subclass) hold named groups of components:
- `ComplianceEngine::Profiles` — keyed by `'profiles'` in source data
- `ComplianceEngine::Ces` — keyed by `'ce'` in source data
- `ComplianceEngine::Checks` — keyed by `'checks'` in source data
- `ComplianceEngine::Controls` — keyed by `'controls'` in source data

**Components** (`ComplianceEngine::Component` subclass) represent individual named entries within those collections:
- `ComplianceEngine::Profile` — a named compliance profile
- `ComplianceEngine::Ce` — a Compliance Element (CE)
- `ComplianceEngine::Check` — a single compliance check; only `type: puppet-class-parameter` checks produce Hiera data via `Check#hiera`
- `ComplianceEngine::Control` — a compliance control

A component can have multiple **fragments** (one per source file), which are deep-merged together via `deep_merge`. Confinement logic in `Component` filters fragments based on Puppet facts, module presence/version, and remediation risk level.

### Central Data Object

`ComplianceEngine::Data` is the primary entry point. It:
1. Loads files via `open(*paths)` which delegates to `ModuleLoader` → `DataLoader::Yaml/Json`
2. Uses Ruby's `Observable` pattern — `DataLoader` objects notify `Data` of changes
3. Lazily constructs and caches the four collection objects; invalidates all caches when facts, enforcement_tolerance, modulepath, or environment_data change
4. Exposes `Data#hiera(profiles)` which walks the check_mapping of requested profiles to produce a flat Hiera-compatible hash

### Business Logic: From Profiles to Hiera

**`Data#hiera(profile_names)`** is the primary output method. It:
1. Resolves each name to a `Profile` object (logs and skips unknown names).
2. Calls `Data#check_mapping(profile)` for each profile to find all associated checks.
3. Filters to checks with `type: 'puppet-class-parameter'`.
4. Calls `Check#hiera` on each, which returns `{ settings['parameter'] => settings['value'] }`.
5. Deep-merges all results into a single flat hash and caches it.

**`Data#check_mapping(profile_or_ce)`** is the correlation engine that links profiles (or CEs) to checks. A check is included if **any** of the following hold (evaluated via `Data#mapping?`):

| Condition | What it checks |
|-----------|---------------|
| Shared **control** | `check.controls` and `profile.controls` share a key set to `true` |
| Shared **CE** | `check.ces` and `profile.ces` share a key set to `true` |
| CE→Control overlap | Any of `check.ces`' CEs has a control that also appears in `profile.controls` |
| Direct reference | `profile.checks[check_key]` is truthy |

`check_mapping` is also called recursively with CE objects (used internally when `check_mapping` walks a profile's CEs). Results are cached by `"#{object.class}:#{object.key}"`.

### Loading Pipeline

```
paths → EnvironmentLoader → ModuleLoader (one per module dir)
                                      → DataLoader::Yaml / DataLoader::Json
                                              ↓ (Observable notify)
                                        ComplianceEngine::Data#update
```

- `EnvironmentLoader` scans a Puppet modulepath for module directories
- `EnvironmentLoader::Zip` handles zip-archived environments
- `ModuleLoader` reads a module's `metadata.json` and discovers compliance data files
- `DataLoader` (and its subclasses) read and parse individual files; they use the Observable pattern to push updates to `Data`

### Puppet Hiera Backend

`lib/puppet/functions/compliance_engine/enforcement.rb` implements the Hiera `lookup_key` function. It:
- Resolves profiles from `compliance_engine::enforcement` and optionally `compliance_markup::enforcement` Hiera keys
- Creates and caches a `ComplianceEngine::Data` object on the Puppet lookup context
- Calls `data.hiera(profiles)` and bulk-caches results for subsequent lookups
- Supports `compliance_markup` backwards compatibility via `compliance_markup_compatibility` option

### Confinement and Enforcement Tolerance

`Component#fragments` filters source fragments based on:
- **Fact confinement** (`confine` key): dot-notation Puppet facts (e.g. `os.release.major`). Values may be a string (exact match), a string prefixed with `!` (negation), or an array (any match). Implemented in `Component#fact_match?`. Fact confinement is skipped when `facts` is `nil`.
- **Module confinement** (`confine.module_name` + `confine.module_version`): checks against `environment_data` (a `{module_name => version}` hash) using semantic versioning. Module confinement only runs when `environment_data` is set (e.g. by `ComplianceEngine::Data#open`).
- **Remediation risk** (`remediation.risk`): when `enforcement_tolerance` is a positive `Integer`, drops fragments where risk level ≥ `enforcement_tolerance` and drops disabled remediations. Only applies to `Check` components.

In practice, only fact confinement is bypassed when `facts` is `nil`; module confinement still applies whenever `environment_data` is available. All confinement and risk/disabled-remediation filtering are effectively bypassed only when both `facts` and `environment_data` are unset and `enforcement_tolerance` is not a positive `Integer` (every fragment is then included). This is useful for offline analysis where system context and enforcement settings are unavailable.

### Code Style

Rubocop is configured via `.rubocop.yml` inheriting from `voxpupuli-test`. Key style choices:
- `compact` class/module nesting style (e.g. `class ComplianceEngine::Data` not nested modules)
- Trailing commas on multiline args/arrays
- Leading dot position for method chaining
- `braces_for_chaining` block delimiters
- Max line length: 200
