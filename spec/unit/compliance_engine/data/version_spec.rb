# frozen_string_literal: true

require 'spec_helper'
require 'compliance_engine'

RSpec.describe ComplianceEngine::Data::Version do
  context 'with a valid version number' do
    subject(:version) { described_class.new('2.0.0') }

    it 'initializes' do
      expect(version).not_to be_nil
      expect(version).to be_instance_of(described_class)
    end

    it 'returns a string' do
      expect(version.to_s).to eq('2.0.0')
    end
  end

  context 'with an invalid version number' do
    subject(:version) { described_class.new('1.0') }

    it 'fails to initialize' do
      expect { version }.to raise_error(ComplianceEngine::Error, %r{Unsupported version})
    end
  end

  context 'with a nil version number' do
    subject(:version) { described_class.new(nil) }

    it 'fails to initialize' do
      expect { version }.to raise_error(ComplianceEngine::Error, %r{Missing version})
    end
  end
end
