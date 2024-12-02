# frozen_string_literal: true

require_relative 'lib/compliance_engine/version'

Gem::Specification.new do |spec|
  spec.name = 'compliance_engine'
  spec.version = ComplianceEngine::VERSION
  spec.authors = ['Steven Pritchard']
  spec.email = ['steve@sicura.us']

  spec.summary = 'Parser for Sicura Compliance Engine data'
  spec.homepage = 'https://sicura.us/'
  spec.required_ruby_version = '>= 2.7.0'

  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/simp/rubygem-simp-compliance_engine'
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.start_with?('bin/', 'test/', 'spec/', 'features/', '.git', '.circleci', 'appveyor')
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'deep_merge', '~> 1.2'
  spec.add_dependency 'thor', '~> 1.3'
  spec.add_dependency 'irb', '~> 1.14'
  spec.add_dependency 'semantic_puppet', '~> 1.1'
  spec.add_dependency 'rubyzip', '~> 2.3'
end
