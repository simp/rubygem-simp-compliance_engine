# frozen_string_literal: true

require_relative 'lib/compliance_engine/version'

Gem::Specification.new do |spec|
  spec.name = 'compliance_engine'
  spec.version = ComplianceEngine::VERSION
  spec.authors = ['Steven Pritchard']
  spec.email = ['steve@sicura.us']
  spec.licenses = ['Apache-2.0']

  spec.summary = 'Parser for Sicura Compliance Engine data'
  spec.homepage = 'https://simp-project.com/docs/sce/'
  spec.required_ruby_version = '>= 2.7.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/simp/rubygem-simp-compliance_engine'
  spec.metadata['changelog_uri'] = "https://github.com/simp/rubygem-simp-compliance_engine/releases/tag/#{spec.version}"
  spec.metadata['bug_tracker_uri'] = 'https://github.com/simp/rubygem-simp-compliance_engine/issues'

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob(['*.gemspec', '*.md', 'LICENSE', 'exe/*', 'lib/**/*.rb']).reject { |f| f.start_with?('lib/puppet/') }
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'deep_merge', '~> 1.2'
  spec.add_dependency 'thor', '~> 1.3'
  spec.add_dependency 'irb', '~> 1.14'
  spec.add_dependency 'semantic_puppet', '~> 1.1'
  spec.add_dependency 'rubyzip', '~> 2.3'
end
