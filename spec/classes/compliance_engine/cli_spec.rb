# frozen_string_literal: true

require 'spec_helper'
require 'compliance_engine/cli'

RSpec.describe ComplianceEngine::CLI do
  subject(:cli) { described_class.new([]) }

  before(:each) do
    allow(binding).to receive(:irb).and_return(true)
  end

  xit 'initializes' do
    pending('TODO: implement mocking of binding.irb')
    expect(cli).not_to be_nil
    expect(cli).to be_instance_of(described_class)
  end
end
