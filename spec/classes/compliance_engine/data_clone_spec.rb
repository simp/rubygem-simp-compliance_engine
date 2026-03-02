# frozen_string_literal: true

require 'spec_helper'
require 'compliance_engine'
require 'compliance_engine/data_loader'

# Tests for ComplianceEngine::Data copy isolation (GitHub issue #34).
#
# Root cause of the original bug:
#   Ruby's clone/dup performs a shallow copy.  Collection instance variables
#   (@ces, @profiles, @checks, @controls) on the copy therefore pointed to the
#   same objects as the source.  When facts= was called on any copy,
#   invalidate_cache propagated those facts into the shared collection,
#   silently affecting all other copies.  The shared @data outer hash had the
#   same problem: open() on one copy leaked new file entries to every other.
#
# Fix (initialize_copy in ComplianceEngine::Data):
#   * Dups the outer @data hash so new file entries stay local to each copy.
#   * Nils out all collection and cache variables so each copy builds its own
#     independent collections the first time they are accessed.

RSpec.describe ComplianceEngine::Data do
  # Compliance data with two OS-specific CEs to make fact confinement
  # clearly observable (only one CE survives per OS).
  let(:compliance_data) do
    {
      'version' => '2.0.0',
      'profiles' => {
        'test_profile' => {
          'ces' => { 'rhel_only_ce' => true, 'debian_only_ce' => true },
        },
      },
      'ce' => {
        'rhel_only_ce' => {
          'title' => 'RHEL Only CE',
          'confine' => { 'os.name' => ['RedHat', 'CentOS'] },
          'controls' => { 'test_control' => true },
        },
        'debian_only_ce' => {
          'title' => 'Debian Only CE',
          'confine' => { 'os.name' => ['Debian', 'Ubuntu'] },
          'controls' => { 'test_control' => true },
        },
      },
      'checks' => {
        'rhel_check' => {
          'type' => 'puppet-class-parameter',
          'settings' => { 'parameter' => 'some::rhel::param', 'value' => true },
          'ces' => ['rhel_only_ce'],
        },
        'debian_check' => {
          'type' => 'puppet-class-parameter',
          'settings' => { 'parameter' => 'some::debian::param', 'value' => true },
          'ces' => ['debian_only_ce'],
        },
      },
    }
  end

  let(:rhel9_facts) { { 'os' => { 'name' => 'RedHat', 'release' => { 'major' => '9' } } } }
  let(:debian_facts) { { 'os' => { 'name' => 'Debian', 'release' => { 'major' => '12' } } } }

  # Extra data used by the data-isolation tests.
  let(:extra_data) do
    { 'version' => '2.0.0', 'ce' => { 'extra_ce' => { 'title' => 'Extra CE' } } }
  end

  # Helper: CE titles whose fragments survive fact-filtering.
  def visible_ce_titles(data_obj)
    data_obj.ces.reject { |_key, value| value.to_h.empty? || value.title.nil? }.transform_values(&:title)
  end

  # ---------------------------------------------------------------------------
  # Baseline: verify single-object fact-filtering works before testing copies.
  # ---------------------------------------------------------------------------
  describe 'baseline single-object fact filtering' do
    subject(:engine) { described_class.new(ComplianceEngine::DataLoader.new(compliance_data)) }

    it 'shows both CEs when facts are nil (no confinement)' do
      engine.facts = nil
      expect(visible_ce_titles(engine).keys).to include('rhel_only_ce', 'debian_only_ce')
    end

    it 'shows only the RHEL CE when facts match RHEL' do
      engine.facts = rhel9_facts
      expect(visible_ce_titles(engine).keys).to include('rhel_only_ce')
      expect(visible_ce_titles(engine).keys).not_to include('debian_only_ce')
    end

    it 'shows only the Debian CE when facts match Debian' do
      engine.facts = debian_facts
      expect(visible_ce_titles(engine).keys).to include('debian_only_ce')
      expect(visible_ce_titles(engine).keys).not_to include('rhel_only_ce')
    end
  end

  # ---------------------------------------------------------------------------
  # Shared isolation examples: run for both #clone and #dup.
  #
  # `source` is a Data object with all four collections pre-computed, which is
  # the hardest-to-isolate case (pre-computed collection objects are stored in
  # instance variables and thus included in the shallow copy).
  # ---------------------------------------------------------------------------
  shared_examples 'copy isolation' do |copy_method|
    let(:source) do
      d = described_class.new(ComplianceEngine::DataLoader.new(compliance_data))
      d.ces
      d.profiles
      d.checks
      d.controls # pre-compute all collections
      d
    end

    # rubocop:disable RSpec/IndexedLet
    let(:copy1) { source.public_send(copy_method) }
    let(:copy2) { source.public_send(copy_method) }
    # rubocop:enable RSpec/IndexedLet

    # --- facts isolation ---

    it 'copies have independent @facts attributes' do
      copy1.facts = rhel9_facts
      copy2.facts = debian_facts
      expect(copy1.facts).to eq(rhel9_facts)
      expect(copy2.facts).to eq(debian_facts)
    end

    it 'copy2 with nil facts sees all CEs (unconfined) even after copy1 sets RHEL facts' do
      copy1.facts = rhel9_facts
      expect(copy2.facts).to be_nil
      # nil facts => no confinement => both CEs should be visible on copy2
      expect(visible_ce_titles(copy2)).to include('debian_only_ce')
    end

    it 'setting Debian facts on copy2 does not strip RHEL CE from copy1' do
      copy1.facts = rhel9_facts
      copy2.facts = debian_facts
      expect(visible_ce_titles(copy2).keys).to include('debian_only_ce')
      expect(visible_ce_titles(copy2).keys).not_to include('rhel_only_ce')
      # copy1's facts are unchanged; RHEL CE must remain visible
      expect(visible_ce_titles(copy1).keys).to include('rhel_only_ce')
    end

    it 'setting nil facts on copy2 does not unconfine copy1' do
      copy1.facts = debian_facts
      expect(visible_ce_titles(copy1).keys).not_to include('rhel_only_ce')
      copy2.facts = nil
      # copy2 with nil facts => unconfined => both CEs visible
      expect(visible_ce_titles(copy2).keys).to include('rhel_only_ce', 'debian_only_ce')
      # copy1 still has Debian facts => RHEL CE must remain hidden
      expect(visible_ce_titles(copy1).keys).not_to include('rhel_only_ce')
    end

    # --- data isolation ---

    it 'new data opened on copy1 is visible on copy1' do
      copy1.open(ComplianceEngine::DataLoader.new(extra_data))
      expect(copy1.ces.keys).to include('extra_ce')
    end

    it 'new data opened on copy1 does not appear on copy2' do
      copy1.open(ComplianceEngine::DataLoader.new(extra_data))
      expect(copy1.ces.keys).to include('extra_ce')
      expect(copy2.ces.keys).not_to include('extra_ce')
    end

    it 'new data opened on copy1 does not appear on the source object' do
      copy1.open(ComplianceEngine::DataLoader.new(extra_data))
      expect(copy1.ces.keys).to include('extra_ce')
      expect(source.ces.keys).not_to include('extra_ce')
    end

    it 'new data opened on copy2 does not appear on copy1' do
      copy2.open(ComplianceEngine::DataLoader.new(extra_data))
      expect(copy2.ces.keys).to include('extra_ce')
      expect(copy1.ces.keys).not_to include('extra_ce')
    end
  end

  # ---------------------------------------------------------------------------
  # Run the shared isolation suite for both copy methods.
  # ---------------------------------------------------------------------------
  describe '#clone isolation' do
    include_examples 'copy isolation', :clone
  end

  describe '#dup isolation' do
    include_examples 'copy isolation', :dup
  end

  # ---------------------------------------------------------------------------
  # Historical bug documentation (clone-specific).
  #
  # These tests retain the detailed root-cause comments that explain exactly
  # how the shared-collection bug manifested before initialize_copy was added.
  # They duplicate some of the shared-example assertions above, but serve as
  # permanent documentation of the specific failure modes.
  # ---------------------------------------------------------------------------
  describe 'historical bug: pre-computed collections were shared across clones' do
    let(:data) do
      d = described_class.new(ComplianceEngine::DataLoader.new(compliance_data))
      # Force all four collection objects to be instantiated before cloning.
      # After this, d.@ces, d.@profiles, d.@checks, d.@controls are non-nil,
      # which triggered the sharing bug via Ruby's shallow clone.
      d.ces
      d.profiles
      d.checks
      d.controls
      d
    end

    # rubocop:disable RSpec/IndexedLet
    let(:clone1) { data.clone }
    let(:clone2) { data.clone }
    # rubocop:enable RSpec/IndexedLet

    it 'clone1 and clone2 have independent @facts attributes' do
      clone1.facts = rhel9_facts
      clone2.facts = debian_facts
      # @facts on each clone is set via plain attr_writer, so this was always
      # independent -- it was the *collection propagation* that was broken.
      expect(clone1.facts).to eq(rhel9_facts)
      expect(clone2.facts).to eq(debian_facts)
    end

    it 'clone2 with nil facts sees all CEs (unconfined), even after clone1 sets RHEL facts' do
      clone1.facts = rhel9_facts

      # Before the fix, the shared Ces collection had @facts == rhel9_facts.
      # clone2.facts was still nil, but clone2.@ces was the same object as
      # clone1.@ces, so clone2.ces applied rhel9 confinement instead of none.
      expect(clone2.facts).to be_nil
      expect(visible_ce_titles(clone2)).to include('debian_only_ce')
    end

    it 'setting Debian facts on clone2 does not strip RHEL CE from clone1' do
      clone1.facts = rhel9_facts

      # Sanity: clone1 can see the RHEL CE before we touch clone2.
      expect(visible_ce_titles(clone1).keys).to include('rhel_only_ce')

      clone2.facts = debian_facts

      # clone2 correctly sees only the Debian CE...
      expect(visible_ce_titles(clone2).keys).to include('debian_only_ce')
      expect(visible_ce_titles(clone2).keys).not_to include('rhel_only_ce')

      # ...but before the fix, the shared collection now had debian_facts, so
      # clone1 also lost visibility of rhel_only_ce.
      expect(visible_ce_titles(clone1).keys).to include('rhel_only_ce')
    end

    it 'setting nil facts on clone2 does not unconfine clone1' do
      clone1.facts = debian_facts
      expect(visible_ce_titles(clone1).keys).not_to include('rhel_only_ce')

      # Matches the bug-report scenario: "Setting facts to nil in clone2...
      # I get unconfined results, then back to clone1 facts display as set
      # for rhel9 but are now unconfined."
      clone2.facts = nil
      expect(visible_ce_titles(clone2).keys).to include('rhel_only_ce', 'debian_only_ce')

      # Before the fix, the shared collection got nil facts here, unconfining
      # clone1 even though clone1.facts was still debian_facts.
      expect(visible_ce_titles(clone1).keys).not_to include('rhel_only_ce')
    end
  end

  # ---------------------------------------------------------------------------
  # Loader refresh isolation.
  #
  # DataLoader::File#refresh detects on-disk changes and calls self.data=,
  # which triggers Observable#notify_observers.  The only registered observer
  # is the original (source) Data object; copies are never added as observers.
  # Data#update then mutates the per-file inner hash inside @data in-place
  # (:version and :content keys).  Because @data.dup is a shallow copy, the
  # copy shares these inner hashes and silently reads the refreshed content
  # the next time it lazily builds its collections.
  #
  # The copy is tested before it has accessed any collections (lazy), which
  # is the scenario that triggers the bug.  A copy that has already cached
  # its collections before the refresh would not be affected regardless.
  # ---------------------------------------------------------------------------
  describe 'loader refresh isolation' do
    let(:original_ce_data) do
      { 'version' => '2.0.0', 'ce' => { 'original_ce' => { 'title' => 'Original CE' } } }
    end

    let(:refreshed_ce_data) do
      { 'version' => '2.0.0', 'ce' => { 'refreshed_ce' => { 'title' => 'Refreshed CE' } } }
    end

    shared_examples 'loader refresh isolation' do |copy_method|
      it 'a loader refresh on the source does not affect a lazily built copy' do
        loader = ComplianceEngine::DataLoader.new(original_ce_data)
        source = described_class.new(loader)

        copy = source.public_send(copy_method)

        # Simulates DataLoader::File#refresh: updating the loader's data
        # notifies the source (the sole registered Observable observer) and
        # causes Data#update to mutate the shared inner @data hash entry
        # in-place.  Without a deeper dup of @data's values, the copy reads
        # refreshed content the next time it lazily builds its collections.
        loader.data = refreshed_ce_data

        expect(source.ces.keys).to include('refreshed_ce')
        expect(source.ces.keys).not_to include('original_ce')
        expect(copy.ces.keys).to include('original_ce')
        expect(copy.ces.keys).not_to include('refreshed_ce')
      end
    end

    describe '#clone' do
      include_examples 'loader refresh isolation', :clone
    end

    describe '#dup' do
      include_examples 'loader refresh isolation', :dup
    end
  end

  # ---------------------------------------------------------------------------
  # Lazily computed collections: guard against future regressions.
  #
  # When collections are never accessed on the source before cloning, each
  # clone lazily creates its own independent collection on first access.
  # This worked correctly before the fix and must continue to work after.
  # ---------------------------------------------------------------------------
  describe 'cloning with lazily computed collections' do
    let(:data) { described_class.new(ComplianceEngine::DataLoader.new(compliance_data)) }
    # rubocop:disable RSpec/IndexedLet
    let(:clone1) { data.clone }
    let(:clone2) { data.clone }
    # rubocop:enable RSpec/IndexedLet

    it 'isolates facts when collections are built after setting facts on each clone' do
      clone1.facts = rhel9_facts
      clone2.facts = debian_facts

      # Each clone lazily creates its own Ces using its own @facts.
      expect(visible_ce_titles(clone1).keys).to include('rhel_only_ce')
      expect(visible_ce_titles(clone1).keys).not_to include('debian_only_ce')
      expect(visible_ce_titles(clone2).keys).to include('debian_only_ce')
      expect(visible_ce_titles(clone2).keys).not_to include('rhel_only_ce')

      # Cross-check: no contamination after both sides have been accessed.
      expect(visible_ce_titles(clone1).keys).to include('rhel_only_ce')
      expect(visible_ce_titles(clone1).keys).not_to include('debian_only_ce')
    end

    it 'isolates facts when collections are lazily built on each clone before setting facts' do
      # Access collections first, then set facts.  Each clone creates its own
      # collection object here, so they remain independent after facts change.
      clone1.ces
      clone2.ces

      clone1.facts = rhel9_facts
      clone2.facts = debian_facts

      expect(visible_ce_titles(clone1).keys).to include('rhel_only_ce')
      expect(visible_ce_titles(clone1).keys).not_to include('debian_only_ce')
      expect(visible_ce_titles(clone2).keys).to include('debian_only_ce')
      expect(visible_ce_titles(clone2).keys).not_to include('rhel_only_ce')

      expect(visible_ce_titles(clone1).keys).to include('rhel_only_ce')
      expect(visible_ce_titles(clone1).keys).not_to include('debian_only_ce')
    end
  end
end
