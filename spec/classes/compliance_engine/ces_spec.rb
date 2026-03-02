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

      # --- source context inheritance ---

      it 'copy starts with source facts and can diverge independently' do
        # Build a Ces from a Data object that already has RHEL facts set,
        # then pre-compute the Ce caches with that context.
        d_rhel = ComplianceEngine::Data.new(ComplianceEngine::DataLoader.new(compliance_data))
        d_rhel.facts = { 'os' => { 'name' => 'RedHat', 'release' => { 'major' => '9' } } }
        src = described_class.new(d_rhel)
        src.each_value(&:to_h) # pre-compute Ce caches with RHEL facts

        copy = src.public_send(copy_method)

        # Copy inherits RHEL facts => RHEL-confined.
        expect(copy['rhel_only_ce'].title).to eq('RHEL Only CE')
        expect(copy['debian_only_ce'].title).to be_nil

        # Diverge: apply Debian facts to the copy only.
        copy.invalidate_cache(debian_data)
        expect(copy['debian_only_ce'].title).to eq('Debian Only CE')
        expect(copy['rhel_only_ce'].title).to be_nil

        # Source Ces is unchanged.
        expect(src['rhel_only_ce'].title).to eq('RHEL Only CE')
        expect(src['debian_only_ce'].title).to be_nil
      end
    end

    describe '#clone isolation' do
      include_examples 'collection copy isolation', :clone
    end

    describe '#dup isolation' do
      include_examples 'collection copy isolation', :dup
    end
  end

  # ---------------------------------------------------------------------------
  # by_oval_id cache isolation.
  #
  # Ces#by_oval_id is a derived cache built from the Ce objects in @collection.
  # initialize_copy clears it so each copy rebuilds from its own (independent)
  # Ce objects.  These tests confirm that applying different facts to two copies
  # produces independent by_oval_id maps, and that a pre-computed @by_oval_id
  # on the source does not leak into the copies.
  # ---------------------------------------------------------------------------
  describe 'by_oval_id cache isolation' do
    let(:oval_data) do
      {
        'version' => '2.0.0',
        'ce' => {
          'rhel_only_ce' => {
            'title' => 'RHEL Only CE',
            'oval-ids' => ['oval:com.example:def:1'],
            'confine' => { 'os.name' => ['RedHat', 'CentOS'] },
          },
          'debian_only_ce' => {
            'title' => 'Debian Only CE',
            'oval-ids' => ['oval:com.example:def:2'],
            'confine' => { 'os.name' => ['Debian', 'Ubuntu'] },
          },
        },
      }
    end

    let(:rhel_data) do
      d = ComplianceEngine::Data.new(ComplianceEngine::DataLoader.new(oval_data))
      d.facts = { 'os' => { 'name' => 'RedHat', 'release' => { 'major' => '9' } } }
      d
    end

    let(:debian_data) do
      d = ComplianceEngine::Data.new(ComplianceEngine::DataLoader.new(oval_data))
      d.facts = { 'os' => { 'name' => 'Debian', 'release' => { 'major' => '12' } } }
      d
    end

    # Source with by_oval_id pre-computed (nil facts => both OVALs present).
    let(:source) do
      c = described_class.new(ComplianceEngine::Data.new(ComplianceEngine::DataLoader.new(oval_data)))
      c.by_oval_id # pre-compute
      c
    end

    shared_examples 'by_oval_id copy isolation' do |copy_method|
      # rubocop:disable RSpec/IndexedLet
      let(:copy1) { source.public_send(copy_method) }
      let(:copy2) { source.public_send(copy_method) }
      # rubocop:enable RSpec/IndexedLet

      it 'each copy rebuilds by_oval_id independently from its own component set' do
        copy1.invalidate_cache(rhel_data)
        copy2.invalidate_cache(debian_data)

        # copy1 (RHEL facts): only the RHEL oval id is visible.
        expect(copy1.by_oval_id.keys).to include('oval:com.example:def:1')
        expect(copy1.by_oval_id.keys).not_to include('oval:com.example:def:2')

        # copy2 (Debian facts): only the Debian oval id is visible.
        expect(copy2.by_oval_id.keys).to include('oval:com.example:def:2')
        expect(copy2.by_oval_id.keys).not_to include('oval:com.example:def:1')
      end

      it 'pre-computed source by_oval_id is not shared with copies' do
        # Source (nil facts) sees both OVALs.
        expect(source.by_oval_id.keys).to include('oval:com.example:def:1', 'oval:com.example:def:2')

        # Copies have @by_oval_id cleared by initialize_copy; after applying
        # RHEL facts only the RHEL oval id should appear.
        copy1.invalidate_cache(rhel_data)
        expect(copy1.by_oval_id.keys).to include('oval:com.example:def:1')
        expect(copy1.by_oval_id.keys).not_to include('oval:com.example:def:2')

        # Source is unaffected.
        expect(source.by_oval_id.keys).to include('oval:com.example:def:1', 'oval:com.example:def:2')
      end
    end

    describe '#clone isolation' do
      include_examples 'by_oval_id copy isolation', :clone
    end

    describe '#dup isolation' do
      include_examples 'by_oval_id copy isolation', :dup
    end
  end
end
