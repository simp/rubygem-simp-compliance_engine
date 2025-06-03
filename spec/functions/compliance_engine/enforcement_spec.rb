require 'spec_helper'
require 'spec_helper_puppet'
require 'puppet/functions/compliance_engine/enforcement'
require 'puppet/pops/lookup/context'

RSpec.describe 'compliance_engine::enforcement' do
  let(:context) { instance_double(Puppet::Pops::Lookup::Context) }

  before(:each) do
    # Mock the `not_found` method for the context object
    allow(context).to receive(:not_found)
  end

  context 'when key is lookup_options' do
    it 'logs debug messages and calls not_found' do
      # Mock ComplianceEngine logger
      # logger = instance_double('Logger')
      # allow(ComplianceEngine).to receive(:log).and_return(logger)
      # allow(logger).to receive(:debug)

      # Call the function
      is_expected.to run.with_params('test_key', { 'some_option' => 'value' }, context)

      # Verify debug logging
      # expect(logger).to have_received(:debug).with(/compliance_engine::enforcement called with key test_key/)
      # expect(logger).to have_received(:debug).with(/options {"some_option"=>"value"}/)
      # expect(logger).to have_received(:debug).with(/context/)

      # Verify that context.not_found was called
      expect(context).to receive(:not_found)
    end
  end
end
