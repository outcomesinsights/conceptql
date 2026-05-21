# frozen_string_literal: true

require_relative '../../../helper'
require 'conceptql'

# Regression coverage for conceptql-pk7: Spark 3.3.2 mis-evaluates the
# multi-WHEN `is_primary` CASE expression in gdm_wide_it when its result feeds
# the outer CASE-with-expression below. The fix emits a single IN-form WHEN
# instead. This test pins the IN-form so a future change cannot silently
# regress to the multi-WHEN form.
describe ConceptQL::Behaviors::Utilizable do
  describe 'gdm_wide is_primary CASE emission' do
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

    let(:cdb) do
      ConceptQL::Database.new(
        Sequel.mock(host: :postgres),
        data_model: :gdm_wide,
        lexicon: stub_lexicon
      )
    end

    let(:sql) { cdb.query(['hospitalization']).sql }

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
end
