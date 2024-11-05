# frozen_string_literal: true

require 'spec_helper'
require 'compliance_engine/data_loader/file'

RSpec.describe ComplianceEngine::DataLoader::File do
  let(:filename) { '/path/to/file' }

  before(:each) do
    allow(File).to receive(:size).and_call_original
    allow(File).to receive(:size).with(filename).and_return(0)

    allow(File).to receive(:mtime).and_call_original
    allow(File).to receive(:mtime).with(filename).and_return(Time.now)

    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:read).with(filename).and_return("\n")
  end

  it 'fails to initialize' do
    expect { described_class.new(filename) }.to raise_error(NoMethodError)
  end
end
