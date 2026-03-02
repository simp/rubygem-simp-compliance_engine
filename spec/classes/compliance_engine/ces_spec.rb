# frozen_string_literal: true

require 'spec_helper'
require 'compliance_engine'
require 'compliance_engine/data_loader'

RSpec.describe ComplianceEngine::Ces do
  subject(:ces) { described_class.new(ComplianceEngine::Data.new) }

  it 'initializes' do
    expect(ces).not_to be_nil
    expect(ces).to be_instance_of(described_class)
  end

  # ---------------------------------------------------------------------------
  # clone/dup isolation (Collection behavior)
  #
  # Ces is used as the concrete Collection subclass.  Source has all Ce caches
  # pre-computed before copying -- the hardest case, because the Component
  # objects inside @collection are included in the shallow copy and share the
  # same invalidate_cache propagation path.
  # ---------------------------------------------------------------------------
  describe 'clone/dup isolation (Collection behavior)' do
    let(:compliance_data) do
      {
        'version' => '2.0.0',
        'ce' => {
          'rhel_only_ce' => {
            'title' => 'RHEL Only CE',
            'confine' => { 'os.name' => ['RedHat', 'CentOS'] },
          },
          'debian_only_ce' => {
            'title' => 'Debian Only CE',
            'confine' => { 'os.name' => ['Debian', 'Ubuntu'] },
          },
        },
      }
    end

    let(:rhel_data) do
      d = ComplianceEngine::Data.new(ComplianceEngine::DataLoader.new(compliance_data))
      d.facts = { 'os' => { 'name' => 'RedHat', 'release' => { 'major' => '9' } } }
      d
    end

    let(:debian_data) do
      d = ComplianceEngine::Data.new(ComplianceEngine::DataLoader.new(compliance_data))
      d.facts = { 'os' => { 'name' => 'Debian', 'release' => { 'major' => '12' } } }
      d
    end

    # Source collection with all Ce caches pre-computed.
    let(:source) do
      c = described_class.new(ComplianceEngine::Data.new(ComplianceEngine::DataLoader.new(compliance_data)))
      c.each_value(&:to_h)
      c
    end

    shared_examples 'collection copy isolation' do |copy_method|
      # rubocop:disable RSpec/IndexedLet
      let(:copy1) { source.public_send(copy_method) }
      let(:copy2) { source.public_send(copy_method) }
      # rubocop:enable RSpec/IndexedLet

      # --- facts isolation ---

      it 'copies have independent facts' do
        copy1.facts = rhel_data.facts
        copy2.facts = debian_data.facts
        expect(copy1.facts).to eq(rhel_data.facts)
        expect(copy2.facts).to eq(debian_data.facts)
      end

      it 'applying RHEL facts to copy1 does not confine copy2 to RHEL' do
        # Without initialize_copy the Ce objects are shared.  invalidate_cache
        # on copy1 propagates rhel facts into those shared Ces, so copy2's
        # rendering also becomes RHEL-confined.
        copy1.invalidate_cache(rhel_data)
        # copy2 components still have nil facts => both CEs unconfined
        expect(copy2['rhel_only_ce'].title).to eq('RHEL Only CE')
        expect(copy2['debian_only_ce'].title).to eq('Debian Only CE')
      end

      it 'each copy reflects its own facts independently' do
        copy1.invalidate_cache(rhel_data)
        copy2.invalidate_cache(debian_data)
        expect(copy1['rhel_only_ce'].title).to eq('RHEL Only CE')
        expect(copy1['debian_only_ce'].title).to be_nil
        expect(copy2['debian_only_ce'].title).to eq('Debian Only CE')
        expect(copy2['rhel_only_ce'].title).to be_nil
      end
    end

    describe '#clone isolation' do
      include_examples 'collection copy isolation', :clone
    end

    describe '#dup isolation' do
      include_examples 'collection copy isolation', :dup
    end
  end
end
