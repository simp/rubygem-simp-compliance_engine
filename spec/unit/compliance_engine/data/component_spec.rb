# frozen_string_literal: true

require 'spec_helper'
require 'compliance_engine'

RSpec.describe ComplianceEngine::Data::Component do
  subject(:component) { described_class.new('key') }

  it 'initializes' do
    expect(component).not_to be_nil
    expect(component).to be_instance_of(described_class)
  end
end
