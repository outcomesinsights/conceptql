# frozen_string_literal: true

require "tmpdir"
require_relative "../../db_helper"

# cpt_or_hcpcs checks its codes as one set across its vocabularies, CPT4,
# HCPCS and CPT4_HCPCS (bead conceptql-0h2n). A code is known when the
# dataset's lexicon has it in any of them. Of the other codes, one that the
# reference lexicon has in any of them is not present in this dataset, and
# the rest are unknown. Each warning appears once, with every code.
describe "the code checks of cpt_or_hcpcs" do
  def bad_format = ConceptQL::Operators::Operator::BAD_FORMAT
  def not_present = ConceptQL::Operators::Vocabulary::NOT_PRESENT_IN_DATASET
  def unknown = ConceptQL::Operators::Operator::UNKNOWN_CODE

  let(:data_model) { CDB.opts[:data_model] }

  def warnings(cdb, statement)
    by_operator(ConceptQL::Annotation.new(cdb.query(statement).annotate).warnings)
  end

  # The fixture's lexicon has 99214 in CPT4 and J9999 in HCPCS. ZZZZZ has the
  # format of none of the three vocabularies (it is a HIPPS code). 00000 and
  # Z9999 have the format of CPT4, and no vocabulary has them.
  it "warns once about the codes that no vocabulary knows, and not about a code that one knows" do
    _(warnings(CDB, %w[cpt_or_hcpcs 99214 J9999 ZZZZZ])).must_equal({ "cpt_or_hcpcs" => [ [ bad_format, "ZZZZZ" ] ] })
    _(warnings(CDB, %w[cpt_or_hcpcs 99214 J9999 ZZZZZ 00000 Z9999]))
      .must_equal({ "cpt_or_hcpcs" => [ [ bad_format, "ZZZZZ" ], [ unknown, "00000", "Z9999" ] ] })
    _(warnings(CDB, %w[cpt_or_hcpcs 99214 J9999])).must_equal({})
  end

  # The dataset's lexicon is a copy, in a temporary DuckDB file, of the
  # fixture's CPT4, HCPCS and CPT4_HCPCS concepts without some codes. The
  # fixture's own vocabulary tables are the reference lexicon.
  describe "with a trimmed dataset lexicon on the DuckDB fixture" do
    before do
      skip "needs the DuckDB fixture (just test-duckdb)" unless DB.database_type.to_sym == :duckdb

      @dir = Dir.mktmpdir
      @full = ConceptQL::Lexicon.for_dataset(DB)
      vocabularies = %w[CPT4 HCPCS CPT4_HCPCS]
      concepts = DB[:concept].where(vocabulary_id: vocabularies)
      # 99213 is in no vocabulary of the trimmed lexicon. 99214 is only in
      # its CPT4_HCPCS, and J9999 is only in its HCPCS.
      removed = Sequel.|({ concept_code: "99213" },
                         { concept_code: "99214", vocabulary_id: "CPT4" },
                         { concept_code: "J9999", vocabulary_id: "CPT4_HCPCS" })
      tables = {
        concept: concepts.exclude(removed),
        vocabulary: DB[:vocabulary].where(vocabulary_id: vocabularies),
        concept_ancestor: DB[:concept_ancestor].where(false),
        concept_relationship: DB[:concept_relationship].where(false)
      }
      tables.each do |name, ds|
        DB.run("COPY (#{ds.sql}) TO #{DB.literal(File.join(@dir, "#{name}.parquet"))} (FORMAT parquet)")
      end
      @trimmed_db = Sequel.connect("duckdb://#{File.join(@dir, "trimmed.duckdb")}")
      tables.each_key do |name|
        @trimmed_db.run("CREATE TABLE #{name} AS SELECT * FROM read_parquet(#{@trimmed_db.literal(File.join(@dir, "#{name}.parquet"))})")
      end
      @trimmed = ConceptQL::Lexicon.new(nil, @trimmed_db, strategy: ConceptQL::LexiconOhdsi.new(@trimmed_db), cache: true)
    end

    after do
      @trimmed_db&.disconnect
      FileUtils.rm_rf(@dir) if @dir
    end

    def dataset_only
      ConceptQL::Database.new(DB, data_model: data_model, lexicon: @trimmed)
    end

    def with_reference
      ConceptQL::Database.new(DB, data_model: data_model, lexicon: @trimmed, reference_lexicon: @full)
    end

    it "keeps the premises of the trimmed lexicon" do
      known = ->(vocabulary_id) { @trimmed.known_codes(DB, vocabulary_id, %w[99213 99214 J9999], check_case: false) }

      _(%w[CPT4 HCPCS CPT4_HCPCS].to_h { [ _1, known.call(_1) ] })
        .must_equal({ "CPT4" => [], "HCPCS" => %w[J9999], "CPT4_HCPCS" => %w[99214] })
      _(@full.known_codes(DB, "CPT4", %w[99213 00000], check_case: false)).must_equal %w[99213]
    end

    it "warns that a code of the reference lexicon only is not present, and that a code of neither is unknown" do
      _(warnings(with_reference, %w[cpt_or_hcpcs 99213 99214 J9999 00000]))
        .must_equal({ "cpt_or_hcpcs" => [ [ not_present, "99213" ], [ unknown, "00000" ] ] })
    end

    it "calls the codes unknown without a reference lexicon" do
      _(warnings(dataset_only, %w[cpt_or_hcpcs 99213 99214 J9999 00000]))
        .must_equal({ "cpt_or_hcpcs" => [ [ unknown, "99213", "00000" ] ] })
    end
  end
end
