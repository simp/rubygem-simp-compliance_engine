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

  describe 'ComplianceEngine.install_puppet_logger' do
    around(:each) do |example|
      original_log = ComplianceEngine.instance_variable_get(:@log)
      example.run
    ensure
      ComplianceEngine.instance_variable_set(:@log, original_log)
    end

    context 'when no logger has been configured' do
      before(:each) { ComplianceEngine.instance_variable_set(:@log, nil) }

      it 'installs a PuppetLogger' do
        ComplianceEngine.install_puppet_logger
        expect(ComplianceEngine.log).to be_a(described_class)
      end
    end

    context 'when a logger is already configured' do
      let(:custom_logger) { instance_double(Logger) }

      before(:each) { ComplianceEngine.log = custom_logger }

      it 'does not overwrite the existing logger' do
        ComplianceEngine.install_puppet_logger
        expect(ComplianceEngine.log).to be(custom_logger)
      end
    end
  end
end
