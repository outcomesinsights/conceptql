# frozen_string_literal: true

require_relative "../../../helper"

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

      it "names the merged vocabularies in one IN list" do
        sql = db.query([ "union", %w[icd9 412], %w[icd10cm I21.0] ]).sql

        _(sql).must_include %(("clinical_code_vocabulary_id" IN ('ICD9CM', 'ICD10CM')))
      end

      it "names a repeated vocabulary once" do
        sql = db.query([ "union", %w[icd9 412], [ "icd9", "*" ] ]).sql

        _(sql).must_include %(("clinical_code_vocabulary_id" IN ('ICD9CM')))
      end

      it "adds no IN list to a single leaf" do
        sql = db.query([ "union", %w[icd9 412] ]).sql

        _(sql).wont_include "IN ('ICD9CM')"
      end

      # Every stream is a set (seed conceptql-0eb, bead conceptql-jib): union
      # removes duplicates, unless no row can come from two of its queries.
      def plain_unions(statement)
        db.query(statement).sql.scan(/\bUNION\b(?! ALL)/).length
      end

      def union_alls(statement)
        db.query(statement).sql.scan(/\bUNION ALL\b/).length
      end

      # Each statement, with its count of UNION and of UNION ALL. A
      # cpt_or_hcpcs joins its own branches with UNION ALL (conceptql-5pz).
      it "removes duplicates when its inputs can overlap" do
        {
          [ "union", [ "first", %w[icd9 412] ], %w[icd9 412] ] => [ 1, 0 ],
          [ "union", [ "icd9", "412", { label: "a" } ], %w[recall a] ] => [ 1, 0 ],
          [ "union", %w[cpt_or_hcpcs 99214], %w[cpt 99215] ] => [ 1, 1 ],
          [ "union", [ "union", %w[icd9 412] ], %w[icd9 486] ] => [ 1, 0 ],
          [ "union", %w[icd9 412], [ "union", %w[icd9 486], %w[cpt 99215] ] ] => [ 1, 1 ]
        }.each do |statement, (unions, alls)|
          _([ plain_unions(statement), union_alls(statement) ]).must_equal [ unions, alls ], statement.inspect
        end
      end

      it "keeps UNION ALL for inputs of different domains" do
        statement = [ "union", %w[icd9 412], %w[cpt 99215], %w[icd10cm I21.0] ]

        _(plain_unions(statement)).must_equal 0
        _(union_alls(statement)).must_equal 1
      end

      it "keeps UNION ALL for inputs of one domain from different vocabularies" do
        statement = [ "union", %w[cpt_or_hcpcs 99214], %w[icd9_procedure 00.66], [ "union", %w[icd9 412] ] ]

        _(plain_unions(statement)).must_equal 0
        _(union_alls(statement)).must_equal 3
      end
    end
  end
end
