# frozen_string_literal: true

require_relative '../../../helper'
require 'conceptql'

# Regression coverage for conceptql-pk7: Spark 3.3.2 mis-evaluates the
# multi-WHEN `is_primary` CASE expression in gdm_wide_it when its result feeds
# the outer CASE-with-expression below. The fix emits a single IN-form WHEN
# instead. This test pins the IN-form so a future change cannot silently
# regress to the multi-WHEN form.
describe ConceptQL::Behaviors::Utilizable do
  # Minimal lexicon stub: returns canned concept IDs for the two vocab
  # lookups gdm_it performs, so all_primary_ids has multiple entries (so the
  # IN list contains more than one literal).
  let(:stub_lexicon) do
    Class.new do
      def concept_ids(_data_db, vocabulary_id, _codes = [])
        case vocabulary_id
        when ConceptQL::DataModel::Gdm.new(nil, nil).file_provenance_types_vocab
          [4001]
        else
          [4002]
        end
      end

      def descendants_of(_data_db, ids)
        ids = Array(ids).flatten
        # Return the requested id(s) plus two fabricated descendants so the
        # IN list has multiple values to detect (and the empty-list code
        # path is not the one being exercised).
        ids + ids.flat_map { |i| [i + 1000, i + 2000] }
      end

      # The lexicon strategy exposes a number of other helpers via
      # `Forwardable`; gdm_wide_it doesn't call them, but a few are
      # referenced during operator initialization.
      def concepts_table(_)
        :concepts
      end

      def concepts(*); end
      def concepts_by_name(*); end
      def concepts_ds(*); end
      def concepts_to_codes(*); end
      def known_codes(*); end
      def related_concept_ids(*); end
    end.new
  end

  let(:db) { Sequel.mock(host: :postgres) }

  let(:cdb) do
    ConceptQL::Database.new(
      db,
      data_model: :gdm_wide,
      lexicon: stub_lexicon
    )
  end

  let(:sql) { cdb.query(['hospitalization']).sql }

  describe 'gdm_wide is_primary CASE emission' do
    it 'renders `provenance_concept_id IN (...)` for the is_primary flag' do
      _(sql).must_match(/CASE WHEN \("provenance_concept_id" IN \([^)]+\)\) THEN 1 ELSE 0 END\) AS "is_primary"/)
    end

    it 'does not emit the Spark-3.3.2-broken multi-WHEN form' do
      # A regression to the multi-WHEN form would produce consecutive
      # `WHEN ("provenance_concept_id" = N) THEN 1` clauses. Spark 3.3.2
      # mis-evaluates that when its result feeds the outer CASE-with-expression.
      _(sql).wont_match(
        /WHEN \("provenance_concept_id" = \d+\) THEN 1 WHEN \("provenance_concept_id" = \d+\) THEN 1/
      )
    end
  end

  describe 'person filter from table windows' do
    let(:windowed_sql) do
      cdb # ConceptQL::Database loads the cold_col extension that add_table_schema needs
      db.add_table_schema(:cohort_windows, [[:person_id], [:start_date], [:end_date]])
      cdb.query(['hospitalization'], scope_opts: { window_table: :cohort_windows }).sql
    end

    let(:person_filter) { '("patient_id" IN (SELECT "person_id" FROM "cohort_windows"))' }

    it 'filters observations to window persons below the ROW_NUMBER' do
      filter_at = windowed_sql.index(person_filter)

      _(filter_at).wont_be_nil
      _(filter_at).must_be :>, windowed_sql.index('ROW_NUMBER()')
      _(windowed_sql.index('FROM "observations" WHERE')).must_be :<, filter_at
    end

    it 'adds no person filter without a table window' do
      _(sql).wont_include('IN (SELECT "person_id"')
    end
  end
end
