# frozen_string_literal: true

require 'spec_helper'
require 'json'

RSpec.describe ComplianceEngine do
  it 'has a version number' do
    expect(ComplianceEngine::VERSION).not_to be_nil
  end

  it 'initializes' do
    compliance_engine = described_class.new
    expect(compliance_engine).not_to be_nil
    expect(compliance_engine).to be_instance_of(ComplianceEngine::Data)
  end

  describe '.schema_path' do
    it 'returns a string' do
      expect(described_class.schema_path).to be_a(String)
    end

    it 'points to an existing file' do
      expect(File.file?(described_class.schema_path)).to be true
    end

    it 'points to the bundled sce-schema.json' do
      expect(File.basename(described_class.schema_path)).to eq('sce-schema.json')
    end
  end

  describe '.schema' do
    subject(:schema) { described_class.schema }

    it 'returns a Hash' do
      expect(schema).to be_a(Hash)
    end

    it 'is valid JSON Schema (has $schema key)' do
      expect(schema['$schema']).to match(%r{json-schema\.org})
    end

    it 'requires version 2.0.0' do
      expect(schema.dig('properties', 'version', 'const')).to eq('2.0.0')
    end

    it 'defines profiles, ce, checks, and controls' do
      expect(schema['properties'].keys).to include('profiles', 'ce', 'checks', 'controls')
    end
  end
end
