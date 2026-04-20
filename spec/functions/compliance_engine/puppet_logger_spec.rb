# frozen_string_literal: true

require 'spec_helper'
require 'spec_helper_puppet'
require 'compliance_engine/puppet_logger'

RSpec.describe ComplianceEngine::PuppetLogger do
  subject(:logger) { described_class.new }

  describe '#debug' do
    before(:each) { allow(Puppet).to receive(:debug) }

    it 'routes to Puppet.debug' do
      logger.debug('a debug message')
      expect(Puppet).to have_received(:debug).with('a debug message')
    end
  end

  describe '#info' do
    before(:each) { allow(Puppet).to receive(:info) }

    it 'routes to Puppet.info' do
      logger.info('an info message')
      expect(Puppet).to have_received(:info).with('an info message')
    end
  end

  describe '#warn' do
    before(:each) { allow(Puppet).to receive(:warning) }

    it 'routes to Puppet.warning' do
      logger.warn('a warn message')
      expect(Puppet).to have_received(:warning).with('a warn message')
    end
  end

  describe '#error' do
    before(:each) { allow(Puppet).to receive(:err) }

    it 'routes to Puppet.err' do
      logger.error('an error message')
      expect(Puppet).to have_received(:err).with('an error message')
    end
  end

  describe '#fatal' do
    before(:each) { allow(Puppet).to receive(:crit) }

    it 'routes to Puppet.crit' do
      logger.fatal('a fatal message')
      expect(Puppet).to have_received(:crit).with('a fatal message')
    end
  end

  describe '#level=' do
    it 'accepts a log level without raising' do
      expect { logger.level = Logger::DEBUG }.not_to raise_error
    end
  end

  describe 'ComplianceEngine.log' do
    around(:each) do |example|
      original_log = ComplianceEngine.instance_variable_get(:@log)
      # Clear the raw instance variable so enforcement.rb installs
      # PuppetLogger even if the file was already required by another spec.
      ComplianceEngine.instance_variable_set(:@log, nil)
      load File.expand_path('../../../lib/puppet/functions/compliance_engine/enforcement.rb', __dir__)
      example.run
    ensure
      ComplianceEngine.instance_variable_set(:@log, original_log)
    end

    it 'is set to a PuppetLogger instance when enforcement.rb is loaded' do
      expect(ComplianceEngine.log).to be_a(described_class)
    end
  end
end
