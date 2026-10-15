# frozen_string_literal: true

require_relative '../../../helper'

describe ConceptQL::Operators::Union do
  # Union merges its vocabulary leaves into one scan whose WHERE is an OR of
  # the leaves' conditions. A plain OR stopped DuckDB's Parquet filter
  # pushdown, so the merged scan also names its vocabularies in one IN list
  # (bead conceptql-agx, seed conceptql-8u6).
  %i[gdm gdm_wide].each do |data_model|
    describe data_model.to_s do
      let(:db) do
        ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: data_model)
      end

      it 'names the merged vocabularies in one IN list' do
        sql = db.query(['union', %w[icd9 412], %w[icd10cm I21.0]]).sql

        _(sql).must_include %(("clinical_code_vocabulary_id" IN ('ICD9CM', 'ICD10CM')))
      end

      it 'names a repeated vocabulary once' do
        sql = db.query(['union', %w[icd9 412], ['icd9', '*']]).sql

        _(sql).must_include %(("clinical_code_vocabulary_id" IN ('ICD9CM')))
      end

      it 'adds no IN list to a single leaf' do
        sql = db.query(['union', %w[icd9 412]]).sql

        _(sql).wont_include 'IN (\'ICD9CM\')'
      end
    end
  end
end
