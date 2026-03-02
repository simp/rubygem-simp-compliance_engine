# frozen_string_literal: true

require 'spec_helper'
require 'compliance_engine'

RSpec.describe ComplianceEngine::Component do
  subject(:component) { described_class.new('key') }

  it 'initializes' do
    expect(component).not_to be_nil
    expect(component).to be_instance_of(described_class)
  end

  context 'with data' do
    let(:test_data) do
      {
        'file0' => { 'merge_key' => ['value0'] },
        'file1' => { 'merge_key' => ['value1'], 'confine' => { 'kernel' => ['Linux'] } },
        'file2' => { 'merge_key' => ['value2'], 'confine' => { 'kernel' => ['windows'] } },
        'file3' => { 'merge_key' => ['value3'], 'confine' => { 'module_name' => 'author-module' } },
        'file4' => { 'merge_key' => ['value4'], 'confine' => { 'module_name' => 'author-module', 'module_version' => '>= 1.0.0 < 2.0.0' } },
      }
    end

    before(:each) do
      test_data.each do |key, value|
        component.add(key, value)
      end
    end

    it 'accepts data' do
      expect(component.to_a).to be_a(Array)
      expect(component.to_a.size).to eq test_data.keys.size
    end

    context 'without confinement' do
      it 'returns merged data' do
        expect(component.to_h).to be_a(Hash)
        expect(component.to_h['merge_key']).to eq(test_data.values.map { |v| v['merge_key'] }.flatten)
      end
    end

    context 'with facts' do
      before(:each) do
        component.invalidate_cache
      end

      it 'includes expected values' do
        component.facts = { 'kernel' => 'Linux' }
        expect(component.to_h).to be_a(Hash)
        expect(component.to_h['merge_key']).to include('value0')
        expect(component.to_h['merge_key']).to include('value1')
        expect(component.to_h['merge_key']).not_to include('value2')
      end

      it 'excludes expected values' do
        component.facts = { 'kernel' => 'Darwin' }
        expect(component.to_h).to be_a(Hash)
        expect(component.to_h['merge_key']).to include('value0')
        expect(component.to_h['merge_key']).not_to include('value1')
        expect(component.to_h['merge_key']).not_to include('value2')
      end
    end

    context 'with environment data' do
      before(:each) do
        component.invalidate_cache
      end

      it 'excludes values based on module name' do
        component.environment_data = { 'unknown_author-other_module' => '1.0.0' }
        expect(component.to_h).to be_a(Hash)
        expect(component.to_h['merge_key']).to include('value0')
        expect(component.to_h['merge_key']).not_to include('value3')
        expect(component.to_h['merge_key']).not_to include('value4')
      end

      it 'includes a value based on module name' do
        component.environment_data = { 'author-module' => '0.1.0' }
        expect(component.to_h).to be_a(Hash)
        expect(component.to_h['merge_key']).to include('value0')
        expect(component.to_h['merge_key']).to include('value3')
        expect(component.to_h['merge_key']).not_to include('value4')
      end

      it 'includes a value based on module name and version' do
        component.environment_data = { 'author-module' => '1.1.0' }
        expect(component.to_h).to be_a(Hash)
        expect(component.to_h['merge_key']).to include('value0')
        expect(component.to_h['merge_key']).to include('value3')
        expect(component.to_h['merge_key']).to include('value4')
      end
    end
  end

  # ---------------------------------------------------------------------------
  # clone/dup isolation
  #
  # Source has all caches pre-computed before copying -- the hardest case,
  # since the cached @element and @fragments objects are included in the
  # shallow copy and must be cleared by initialize_copy.
  # ---------------------------------------------------------------------------
  describe 'clone/dup isolation' do
    let(:source) do
      c = described_class.new('test_key')
      c.add('file_linux', { 'merge_key' => ['value_linux'], 'confine' => { 'kernel' => ['Linux'] } })
      c.add('file_darwin', { 'merge_key' => ['value_darwin'], 'confine' => { 'kernel' => ['Darwin'] } })
      c.add('file_any', { 'merge_key' => ['value_any'] })
      c.to_h # pre-compute @element and @fragments before copying
      c
    end

    shared_examples 'component copy isolation' do |copy_method|
      # rubocop:disable RSpec/IndexedLet
      let(:copy1) { source.public_send(copy_method) }
      let(:copy2) { source.public_send(copy_method) }
      # rubocop:enable RSpec/IndexedLet

      # --- facts isolation ---

      it 'copies have independent facts' do
        copy1.facts = { 'kernel' => 'Linux' }
        copy2.facts = { 'kernel' => 'Darwin' }
        expect(copy1.facts).to eq({ 'kernel' => 'Linux' })
        expect(copy2.facts).to eq({ 'kernel' => 'Darwin' })
      end

      it 'each copy reflects its own facts independently' do
        # Without initialize_copy the pre-computed @element is shared and
        # stale, so copy1 would return unconfined results even after setting
        # Linux facts (the cached nil-facts element is returned instead).
        copy1.facts = { 'kernel' => 'Linux' }
        copy2.facts = { 'kernel' => 'Darwin' }
        expect(copy1.to_h['merge_key']).to include('value_linux', 'value_any')
        expect(copy1.to_h['merge_key']).not_to include('value_darwin')
        expect(copy2.to_h['merge_key']).to include('value_darwin', 'value_any')
        expect(copy2.to_h['merge_key']).not_to include('value_linux')
      end

      # --- data isolation ---

      it 'a fragment added to copy1 does not appear in copy2' do
        # Without initialize_copy the inner fragments hash is shared, so
        # add on copy1 writes into copy2's fragment store too.
        copy1.add('file_new', { 'merge_key' => ['value_new'] })
        expect(copy1.to_a.map { |f| f['merge_key'] }.flatten).to include('value_new')
        expect(copy2.to_a.map { |f| f['merge_key'] }.flatten).not_to include('value_new')
      end

      it 'a fragment added to copy1 does not appear in the source' do
        copy1.add('file_new', { 'merge_key' => ['value_new'] })
        expect(copy1.to_a.map { |f| f['merge_key'] }.flatten).to include('value_new')
        expect(source.to_a.map { |f| f['merge_key'] }.flatten).not_to include('value_new')
      end

      # --- source context inheritance ---

      it 'copy starts with source facts and can diverge independently' do
        # Build a component that has Linux facts already set and cached,
        # simulating the case where the source has pre-existing context.
        src = described_class.new('inherit_key')
        src.add('file_linux', { 'merge_key' => ['value_linux'], 'confine' => { 'kernel' => ['Linux'] } })
        src.add('file_darwin', { 'merge_key' => ['value_darwin'], 'confine' => { 'kernel' => ['Darwin'] } })
        src.add('file_any', { 'merge_key' => ['value_any'] })
        src.facts = { 'kernel' => 'Linux' }
        src.to_h # pre-compute with Linux facts

        copy = src.public_send(copy_method)

        # Copy inherits Linux facts and renders them correctly.
        expect(copy.facts).to eq({ 'kernel' => 'Linux' })
        expect(copy.to_h['merge_key']).to include('value_linux', 'value_any')
        expect(copy.to_h['merge_key']).not_to include('value_darwin')

        # Diverge: Component#invalidate_cache with no argument clears context
        # variables (setting them to nil) as well as caches.
        copy.invalidate_cache
        expect(copy.to_h['merge_key']).to include('value_linux', 'value_darwin', 'value_any')

        # Source is unchanged.
        expect(src.facts).to eq({ 'kernel' => 'Linux' })
        expect(src.to_h['merge_key']).not_to include('value_darwin')
      end
    end

    describe '#clone isolation' do
      include_examples 'component copy isolation', :clone
    end

    describe '#dup isolation' do
      include_examples 'component copy isolation', :dup
    end
  end
end
