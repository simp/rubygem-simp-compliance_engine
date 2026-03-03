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
#   * Deep-copies each per-file inner hash via transform_values and clears
#     :loader in each entry so file entries and loader references stay local
#     to the copy.
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
  # Data#update mutates the source's per-file inner hash in-place (:version
  # and :content keys).  initialize_copy deep-copies these inner hashes so
  # the copy has its own independent entry that is unaffected by the refresh.
  #
  # The copy is tested before it has accessed any collections (lazy), which
  # is the case where an unprotected shallow copy would be most vulnerable.
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
        # causes Data#update to mutate the source's inner @data hash entry
        # in-place.  The copy's inner hash is independent (deep-copied by
        # initialize_copy) so it retains the original content.
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
  # enforcement_tolerance isolation.
  #
  # enforcement_tolerance= calls invalidate_cache just like facts= does.
  # These tests confirm that copies have independent enforcement_tolerance
  # values and that each copy's checks are filtered by its own tolerance,
  # not the other copy's.
  # ---------------------------------------------------------------------------
  describe 'enforcement_tolerance isolation' do
    # Two checks with different remediation risk levels.  With
    # enforcement_tolerance = 30, fragments whose risk level >= 30 are dropped.
    let(:risk_data) do
      {
        'version' => '2.0.0',
        'checks' => {
          'low_risk_check' => {
            'type' => 'puppet-class-parameter',
            'settings' => { 'parameter' => 'mod::low', 'value' => true },
            'remediation' => { 'risk' => [{ 'level' => 20 }] },
          },
          'high_risk_check' => {
            'type' => 'puppet-class-parameter',
            'settings' => { 'parameter' => 'mod::high', 'value' => true },
            'remediation' => { 'risk' => [{ 'level' => 40 }] },
          },
        },
      }
    end

    let(:source) do
      d = described_class.new(ComplianceEngine::DataLoader.new(risk_data))
      d.checks # pre-compute
      d
    end

    shared_examples 'enforcement_tolerance copy isolation' do |copy_method|
      # rubocop:disable RSpec/IndexedLet
      let(:copy1) { source.public_send(copy_method) }
      let(:copy2) { source.public_send(copy_method) }
      # rubocop:enable RSpec/IndexedLet

      it 'copies have independent enforcement_tolerance' do
        copy1.enforcement_tolerance = 30
        copy2.enforcement_tolerance = 50
        expect(copy1.enforcement_tolerance).to eq(30)
        expect(copy2.enforcement_tolerance).to eq(50)
      end

      it 'high-risk check excluded on copy1 (tol=30) remains visible on copy2 (tol=nil)' do
        copy1.enforcement_tolerance = 30 # risk 40 >= 30 => excluded
        expect(copy1.checks['high_risk_check'].to_h).to be_empty
        expect(copy2.checks['high_risk_check'].to_h).not_to be_empty
      end
    end

    describe '#clone isolation' do
      include_examples 'enforcement_tolerance copy isolation', :clone
    end

    describe '#dup isolation' do
      include_examples 'enforcement_tolerance copy isolation', :dup
    end
  end

  # ---------------------------------------------------------------------------
  # environment_data isolation.
  #
  # environment_data= also calls invalidate_cache.  These tests confirm that
  # copies have independent environment_data and that module-confined checks
  # are filtered correctly per copy.
  # ---------------------------------------------------------------------------
  describe 'environment_data isolation' do
    # One check confined to a specific Puppet module; only visible when that
    # module is present in environment_data.
    let(:module_data) do
      {
        'version' => '2.0.0',
        'checks' => {
          'module_check' => {
            'type' => 'puppet-class-parameter',
            'settings' => { 'parameter' => 'mod::param', 'value' => true },
            'confine' => { 'module_name' => 'author-module' },
          },
        },
      }
    end

    let(:source) do
      d = described_class.new(ComplianceEngine::DataLoader.new(module_data))
      d.checks # pre-compute
      d
    end

    shared_examples 'environment_data copy isolation' do |copy_method|
      # rubocop:disable RSpec/IndexedLet
      let(:copy1) { source.public_send(copy_method) }
      let(:copy2) { source.public_send(copy_method) }
      # rubocop:enable RSpec/IndexedLet

      it 'copies have independent environment_data' do
        copy1.environment_data = { 'author-module' => '1.0.0' }
        copy2.environment_data = { 'other-module' => '2.0.0' }
        expect(copy1.environment_data).to eq({ 'author-module' => '1.0.0' })
        expect(copy2.environment_data).to eq({ 'other-module' => '2.0.0' })
      end

      it 'module-confined check visible on copy1 is excluded on copy2' do
        copy1.environment_data = { 'author-module' => '1.0.0' }
        copy2.environment_data = { 'other-module' => '2.0.0' }
        expect(copy1.checks['module_check'].to_h).not_to be_empty
        expect(copy2.checks['module_check'].to_h).to be_empty
      end
    end

    describe '#clone isolation' do
      include_examples 'environment_data copy isolation', :clone
    end

    describe '#dup isolation' do
      include_examples 'environment_data copy isolation', :dup
    end
  end

  # ---------------------------------------------------------------------------
  # Source context is inherited by copies.
  #
  # When the source has context (facts, etc.) already set before cloning, the
  # copy should start with that same context and render accordingly.  It must
  # also be able to diverge independently without affecting the source.
  # ---------------------------------------------------------------------------
  describe 'source context is inherited by copies' do
    let(:source) do
      d = described_class.new(ComplianceEngine::DataLoader.new(compliance_data))
      d.facts = rhel9_facts
      d.ces # pre-compute with RHEL facts
      d
    end

    shared_examples 'source context inherited' do |copy_method|
      let(:copy) { source.public_send(copy_method) }

      it 'copy starts with the source facts and applies them correctly' do
        expect(copy.facts).to eq(rhel9_facts)
        expect(visible_ce_titles(copy).keys).to include('rhel_only_ce')
        expect(visible_ce_titles(copy).keys).not_to include('debian_only_ce')
      end

      it 'copy can diverge from the source context without affecting the source' do
        copy.facts = nil
        expect(visible_ce_titles(copy).keys).to include('rhel_only_ce', 'debian_only_ce')
        expect(source.facts).to eq(rhel9_facts)
        expect(visible_ce_titles(source).keys).to include('rhel_only_ce')
        expect(visible_ce_titles(source).keys).not_to include('debian_only_ce')
      end
    end

    describe '#clone' do
      include_examples 'source context inherited', :clone
    end

    describe '#dup' do
      include_examples 'source context inherited', :dup
    end
  end

  # ---------------------------------------------------------------------------
  # Shared loader isolation.
  #
  # initialize_copy clears :loader from each per-file inner hash so the copy
  # does not hold a reference to the source's DataLoader object.  A shared
  # loader would allow the copy to trigger loader.refresh via update(key),
  # which would notify the source (the registered Observable observer) and
  # overwrite source.data[key][:content] while the copy's inner hash stayed
  # stale.  With :loader nil the copy creates its own independent loader (and
  # registers itself as observer) the next time it opens that file.
  # ---------------------------------------------------------------------------
  describe 'shared loader isolation' do
    let(:initial_data) do
      { 'version' => '2.0.0', 'ce' => { 'original_ce' => { 'title' => 'Original CE' } } }
    end

    let(:loader) { ComplianceEngine::DataLoader.new(initial_data) }
    let(:source) { described_class.new(loader) }

    shared_examples 'shared loader copy isolation' do |copy_method|
      it 'copy @data entries have the loader reference cleared' do
        # initialize_copy sets entry[:loader] to nil so the copy holds no
        # reference to the source's DataLoader.  This prevents the copy from
        # accidentally triggering loader.refresh via update(key_string), which
        # would notify the source (the registered Observable observer) and
        # overwrite source.data[key][:content] while the copy's inner hash
        # stayed stale.
        copy = source.public_send(copy_method)
        copy.data.each_value do |entry|
          expect(entry[:loader]).to be_nil
        end
      end
    end

    describe '#clone' do
      include_examples 'shared loader copy isolation', :clone
    end

    describe '#dup' do
      include_examples 'shared loader copy isolation', :dup
    end
  end

  # ---------------------------------------------------------------------------
  # Observer re-subscription after clone/dup.
  #
  # initialize_copy sets :loader to nil in each @data entry so the copy does
  # not hold a reference to the source's loader.  When the copy later calls
  # open(loader) for a key already present in @data, the else branch of
  # Data#update checks the :loader VALUE (not just key presence) to decide
  # whether to register the copy as an observer.  A nil value is correctly
  # treated as "not yet registered", so add_observer is called and the copy
  # receives future loader refreshes independently from the source.
  # ---------------------------------------------------------------------------
  describe 'observer re-subscription after clone/dup' do
    let(:initial_data) do
      { 'version' => '2.0.0', 'ce' => { 'original_ce' => { 'title' => 'Original CE' } } }
    end

    let(:refreshed_data) do
      { 'version' => '2.0.0', 'ce' => { 'refreshed_ce' => { 'title' => 'Refreshed CE' } } }
    end

    let(:loader) { ComplianceEngine::DataLoader.new(initial_data, key: 'observer_test_loader') }
    let(:source) { described_class.new(loader) }

    shared_examples 'observer re-subscription' do |copy_method|
      it 'copy receives loader refreshes after re-opening a known loader key' do
        copy = source.public_send(copy_method)

        # Re-open the same loader on the copy.  initialize_copy nil'd the
        # :loader entry so the copy must register itself as a new observer.
        copy.open(loader)

        # Refresh the loader.  Both source and copy must be notified so each
        # rebuilds its collections from the refreshed content.
        loader.data = refreshed_data

        expect(source.ces.keys).to include('refreshed_ce')
        expect(source.ces.keys).not_to include('original_ce')
        expect(copy.ces.keys).to include('refreshed_ce')
        expect(copy.ces.keys).not_to include('original_ce')
      end
    end

    describe '#clone' do
      include_examples 'observer re-subscription', :clone
    end

    describe '#dup' do
      include_examples 'observer re-subscription', :dup
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
