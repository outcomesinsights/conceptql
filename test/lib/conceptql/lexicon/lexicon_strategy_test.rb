# frozen_string_literal: true

require_relative '../../../helper'

describe ConceptQL::LexiconStrategy do
  # LexiconGDM is the thinnest concrete strategy — its concepts_table is just
  # db[:concepts], so a mock DB is enough to exercise the base-class method.
  let(:db) { Sequel.mock(host: :postgres) }
  let(:lexicon) { ConceptQL::LexiconGDM.new(db) }

  describe '#concepts vocabulary guard' do
    # There is no wildcard lookup. '*' is meaningful only in `arguments`, where
    # Vocabulary#select_all? skips the lexicon call. Honouring it here read as
    # support for cross-vocabulary lookup that has never existed.
    it 'raises rather than silently matching every vocabulary for "*"' do
      err = _ { lexicon.concepts(db, '*') }.must_raise ArgumentError
      _(err.message).must_match(/specific vocabulary/)
    end

    it 'raises for an Array containing "*"' do
      _ { lexicon.concepts(db, ['*']) }.must_raise ArgumentError
    end

    it 'raises for nil' do
      _ { lexicon.concepts(db, nil) }.must_raise ArgumentError
    end

    it 'raises for an empty string' do
      _ { lexicon.concepts(db, '') }.must_raise ArgumentError
    end

    # where(vocabulary_id: []) matches nothing, so an empty Array is the same
    # silent-empty-result bug the raise exists to prevent.
    it 'raises for an empty Array' do
      _ { lexicon.concepts(db, []) }.must_raise ArgumentError
    end
  end

  describe '#concepts accepts every shape callers actually pass' do
    # The guard must not be a type check: these three shapes are all live.
    it 'accepts a String vocabulary and filters on it' do
      sql = lexicon.concepts(db, 'ICD9CM').sql
      _(sql).must_match(/"vocabulary_id" = 'ICD9CM'/)
    end

    # ReadOmop#vocabulary_id returns the Integer 17.
    it 'accepts an Integer vocabulary' do
      sql = lexicon.concepts(db, 17).sql
      _(sql).must_match(/"vocabulary_id" = 17/)
    end

    # utilizable.rb and provenanceable.rb pass the provenance-type pairs, which
    # Sequel renders as an IN clause.
    it 'accepts an Array of vocabularies and renders an IN clause' do
      sql = lexicon.concepts(db, %w[JIGSAW_FILE_PROVENANCE_TYPE JS_FILE_PROV_TYPE]).sql
      _(sql).must_match(/"vocabulary_id" IN \('JIGSAW_FILE_PROVENANCE_TYPE', 'JS_FILE_PROV_TYPE'\)/)
    end

    it 'still filters by code alongside the vocabulary' do
      sql = lexicon.concepts(db, 'ICD9CM', ['250.00']).sql
      _(sql).must_match(/"vocabulary_id" = 'ICD9CM'/)
      _(sql).must_match(/lower\("concept_code"\) IN \('250.00'\)/)
    end

    # The vocabulary filter is now unconditional — nothing can produce an
    # unscoped concepts query.
    it 'always scopes by vocabulary even with no codes' do
      _(lexicon.concepts(db, 'ICD9CM').sql).must_match(/WHERE .*"vocabulary_id"/)
    end
  end
end
