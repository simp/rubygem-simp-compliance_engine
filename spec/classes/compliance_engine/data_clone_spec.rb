# frozen_string_literal: true

require 'spec_helper'
require 'compliance_engine'
require 'compliance_engine/data_loader'

# These tests expose the clone isolation bug described in GitHub issue #34.
#
# Root cause:
#   Ruby's `clone`/`dup` performs a shallow copy, so the collection instance
#   variables (@ces, @profiles, @checks, @controls) on the clone point to the
#   *same* object instances as the source.
#
#   When `Data#invalidate_cache` is called (e.g. after `facts=`), it calls
#   `collection.invalidate_cache(self)` on each collection -- which copies the
#   caller's @facts down into the shared collection and all its components.
#
#   Because both clones share the same collection objects, the most recent
#   `facts=` call on *either* clone wins for *all* clones.
#
# Tests in the "pre-computed collections" context are expected to FAIL,
# demonstrating the bug.  Tests in the "lazily computed collections" context
# document the currently-working case and guard against regressions.

RSpec.describe ComplianceEngine::Data do
  # Compliance data with two OS-specific CEs plus a profile that references
  # both.  The confines let us observe which CE(s) survive fact-filtering.
  let(:compliance_data) do
    {
      'version' => '2.0.0',
      'profiles' => {
        'test_profile' => {
          'ces' => {
            'rhel_only_ce' => true,
            'debian_only_ce' => true,
          },
          # Profile-level confine is intentionally omitted so that
          # check_mapping always finds checks regardless of facts.
          # Confinement is exercised at the CE level below.
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

  # Helper: returns the titles of CEs whose fragments are not all confined away
  def visible_ce_titles(data_obj)
    data_obj.ces.reject { |_key, value| value.to_h.empty? || value.title.nil? }.transform_values(&:title)
  end

  # -------------------------------------------------------------------------
  # Baseline: verify the single-object (no-clone) behavior is correct.
  # These must all pass; if they fail, the test data is wrong.
  # -------------------------------------------------------------------------
  describe 'baseline single-object fact filtering (must pass)' do
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

  # -------------------------------------------------------------------------
  # Pre-computed collections scenario.
  #
  # When `data.ces` (or any other collection accessor) is called on the
  # *source* object before cloning, the resulting Ces/Profiles/Checks objects
  # are stored in instance variables.  A subsequent `data.clone` copies those
  # *references*, so clone1.@ces and clone2.@ces point to the same object.
  # -------------------------------------------------------------------------
  describe 'cloning with pre-computed collections (demonstrates the bug)' do
    let(:data) do
      d = described_class.new(ComplianceEngine::DataLoader.new(compliance_data))
      # Force all four collection objects to be instantiated.
      # After this, d.@ces, d.@profiles, d.@checks, d.@controls are non-nil.
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

    # --- facts isolation on the Data objects themselves ---

    it 'clone1 and clone2 have independent @facts attributes' do
      clone1.facts = rhel9_facts
      clone2.facts = debian_facts
      # @facts on each clone is set via plain attr_writer, so this is always
      # independent -- it is the *collection* propagation that is broken.
      expect(clone1.facts).to eq(rhel9_facts)
      expect(clone2.facts).to eq(debian_facts)
    end

    # --- CE visibility isolation ---

    it 'clone2 with nil facts sees all CEs (unconfined), even after clone1 sets RHEL facts' do
      clone1.facts = rhel9_facts

      # After this call, the shared Ces collection has @facts == rhel9_facts.
      # clone2.facts is still nil, but clone2.@ces == clone1.@ces (shared!),
      # so clone2.ces sees rhel9 confinement instead of nil (unconfined).
      expect(clone2.facts).to be_nil

      # With nil facts, NO confinement should be applied, so both CEs should
      # be visible.  This assertion FAILS because the shared Ces collection
      # carries rhel9 facts, hiding the Debian CE from clone2.
      expect(visible_ce_titles(clone2)).to include('debian_only_ce')
    end

    it 'setting Debian facts on clone2 does not strip RHEL CE from clone1' do
      clone1.facts = rhel9_facts

      # Sanity: clone1 can see the RHEL CE before we touch clone2.
      expect(visible_ce_titles(clone1).keys).to include('rhel_only_ce')

      clone2.facts = debian_facts

      # After this call the shared Ces collection has @facts == debian_facts.
      # clone2 correctly sees only the Debian CE...
      expect(visible_ce_titles(clone2).keys).to include('debian_only_ce')
      expect(visible_ce_titles(clone2).keys).not_to include('rhel_only_ce')

      # ...but clone1 should still see the RHEL CE because *its* facts are
      # still rhel9.  This assertion FAILS: the shared collection now has
      # debian_facts, so clone1 also loses visibility of rhel_only_ce.
      expect(visible_ce_titles(clone1).keys).to include('rhel_only_ce')
    end

    it 'setting nil facts on clone2 does not unconfine clone1' do
      clone1.facts = debian_facts

      # Sanity: with Debian facts, RHEL CE is NOT visible on clone1.
      # NOTE: setting clone1.facts also poisoned the shared Ces collection
      # with debian_facts, so even clone2 (which has nil facts) currently
      # sees only the Debian CE -- that is the bug in clone2's direction.
      expect(visible_ce_titles(clone1).keys).not_to include('rhel_only_ce')

      # Explicitly set nil on clone2.  This matches the bug-report scenario:
      # "Setting facts to nil in clone2...I get unconfined results, then
      # back to clone1 facts display as set for rhel9 but are now unconfined".
      # The call triggers invalidate_cache on the *shared* Ces collection,
      # propagating nil to every Ce component in it.
      clone2.facts = nil

      # clone2 with nil facts should now see ALL CEs (unconfined).
      expect(visible_ce_titles(clone2).keys).to include('rhel_only_ce', 'debian_only_ce')

      # clone1's facts are still Debian, so the RHEL CE should remain hidden.
      # This assertion FAILS: the shared collection now has nil facts (set
      # when clone2.facts = nil propagated through it), so clone1 is also
      # unconfined and incorrectly shows the RHEL CE.
      expect(visible_ce_titles(clone1).keys).not_to include('rhel_only_ce')
    end

    it 'fact changes on clone1 do not affect profiles in clone2' do
      clone1.facts = rhel9_facts
      clone2.facts = debian_facts

      # Both Profiles collections are shared; after clone2.facts = debian,
      # the shared Profiles collection has debian_facts.
      # clone1's profile should reflect rhel9 facts, not debian.
      rhel_profile_ces = clone1.profiles['test_profile'].ces
      expect(rhel_profile_ces).to include('rhel_only_ce')
    end
  end

  # -------------------------------------------------------------------------
  # Data isolation: opening new data on one clone must not affect others.
  #
  # After a shallow clone, @data points to the same Hash object in every clone.
  # Calling open() on clone1 invokes update(), which writes a new key into that
  # shared hash, making the new file visible to clone2 as well.  The fix is to
  # dup the outer @data hash in initialize_copy so each clone owns its own map
  # of file keys to content entries.
  # -------------------------------------------------------------------------
  describe 'opening new data on a clone does not affect other clones' do
    let(:extra_data) do
      {
        'version' => '2.0.0',
        'ce' => {
          'extra_ce' => { 'title' => 'Extra CE' },
        },
      }
    end

    let(:data) { described_class.new(ComplianceEngine::DataLoader.new(compliance_data)) }
    # rubocop:disable RSpec/IndexedLet
    let(:clone1) { data.clone }
    let(:clone2) { data.clone }
    # rubocop:enable RSpec/IndexedLet

    it 'new data opened on clone1 is visible on clone1' do
      clone1.open(ComplianceEngine::DataLoader.new(extra_data))
      expect(clone1.ces.keys).to include('extra_ce')
    end

    it 'new data opened on clone1 does not appear on clone2' do
      clone1.open(ComplianceEngine::DataLoader.new(extra_data))
      expect(clone1.ces.keys).to include('extra_ce')
      # clone2 shares the same original data but must not see extra_ce
      expect(clone2.ces.keys).not_to include('extra_ce')
    end

    it 'new data opened on clone1 does not appear on the source object' do
      clone1.open(ComplianceEngine::DataLoader.new(extra_data))
      expect(clone1.ces.keys).to include('extra_ce')
      expect(data.ces.keys).not_to include('extra_ce')
    end

    it 'new data opened on clone2 does not appear on clone1' do
      clone2.open(ComplianceEngine::DataLoader.new(extra_data))
      expect(clone2.ces.keys).to include('extra_ce')
      expect(clone1.ces.keys).not_to include('extra_ce')
    end
  end

  # -------------------------------------------------------------------------
  # Lazily computed collections scenario.
  #
  # If collections are never accessed on the *source* object before cloning,
  # each clone will lazily create its own independent collection objects the
  # first time they are accessed.  This currently works correctly and these
  # tests document / guard that behaviour.
  # -------------------------------------------------------------------------
  describe 'cloning with lazily computed collections (currently works)' do
    # NOTE: data.ces / data.profiles are deliberately NOT called here.
    let(:data) { described_class.new(ComplianceEngine::DataLoader.new(compliance_data)) }
    # rubocop:disable RSpec/IndexedLet
    let(:clone1) { data.clone }
    let(:clone2) { data.clone }
    # rubocop:enable RSpec/IndexedLet

    it 'isolates facts when collections are built after setting facts on each clone' do
      # Set facts before the first collection access on either clone.
      clone1.facts = rhel9_facts
      clone2.facts = debian_facts

      # Each clone lazily creates its own Ces from scratch using its own @facts.
      expect(visible_ce_titles(clone1).keys).to include('rhel_only_ce')
      expect(visible_ce_titles(clone1).keys).not_to include('debian_only_ce')

      expect(visible_ce_titles(clone2).keys).to include('debian_only_ce')
      expect(visible_ce_titles(clone2).keys).not_to include('rhel_only_ce')

      # Cross-check: neither clone is contaminated after both are accessed.
      expect(visible_ce_titles(clone1).keys).to include('rhel_only_ce')
      expect(visible_ce_titles(clone1).keys).not_to include('debian_only_ce')
    end

    it 'isolates facts when collections are lazily built on each clone before setting facts' do
      # Access collections first (before setting any facts), then set facts.
      # Each clone creates its own collection object at this point.
      clone1.ces
      clone2.ces

      clone1.facts = rhel9_facts
      clone2.facts = debian_facts

      expect(visible_ce_titles(clone1).keys).to include('rhel_only_ce')
      expect(visible_ce_titles(clone1).keys).not_to include('debian_only_ce')

      expect(visible_ce_titles(clone2).keys).to include('debian_only_ce')
      expect(visible_ce_titles(clone2).keys).not_to include('rhel_only_ce')

      # Verify no cross-contamination after both sides have been accessed.
      expect(visible_ce_titles(clone1).keys).to include('rhel_only_ce')
      expect(visible_ce_titles(clone1).keys).not_to include('debian_only_ce')
    end
  end
end
