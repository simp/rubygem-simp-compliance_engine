# frozen_string_literal: true

require 'spec_helper'
require 'compliance_engine'

RSpec.describe ComplianceEngine::Data::Collection do
  subject(:collection) { described_class.new(ComplianceEngine::Data.new) }

  it 'does not initialize' do
    expect { collection }.to raise_error(NotImplementedError)
  end
end
