# frozen_string_literal: true

require_relative "../../../db_helper"

# A selection operator warns when a selected code has more than one name in
# the vocabulary, because the vocabulary reused the code for a new meaning
# (conceptql-ttk). DRG 410 and 492 meant chemotherapy until 2007-09-30. From
# 2007-10-01 they mean a biliary tract procedure and a lower extremity
# procedure.
describe "the warning for codes with more than one meaning" do
  def warnings_for(cdb, statement)
    cdb.query(statement).annotate.last[:annotation][:warnings]
  end

  it "names each reused code and all of its meanings" do
    _(warnings_for(CDB, %w[drg 410 492 870])).must_equal [
      [
        "code(s) with more than one meaning",
        "410: Biliary tract proc except only cholecyst w or w/o c.d.e. w/o CC/MCC | " \
        "Chemotherapy without Acute Leukemia As Secondary Diagnosis",
        "492: Chemotherapy W/ Acute Leukemia As Secondary Diagnosis | " \
        "Chemotherapy W/ Acute Leukemia As Secondary Diagnosis or with Use of High-Dose Chemotherapy Agent | " \
        "Lower extrem & humer proc except hip,foot,femur w MCC"
      ]
    ]
  end

  it "gives no warning for a code with one meaning" do
    _(warnings_for(CDB, %w[drg 870])).must_be_nil
  end

  describe "with a small OHDSI lexicon" do
    let(:lexicon_db) do
      Sequel.connect("sqlite:/").tap do |db|
        db.create_table(:vocabulary) do
          String :vocabulary_id
          String :vocabulary_name
        end
        db.create_table(:concept_ancestor) { String :column }
        db.create_table(:concept_relationship) { String :column }
        db.create_table(:concept) do
          Integer :concept_id
          String :concept_code
          String :concept_name
          String :vocabulary_id
        end
        db[:vocabulary].insert(vocabulary_id: "DRG", vocabulary_name: "DRG")
        db[:concept].multi_insert([
                                    { concept_id: 1, concept_code: "410", concept_name: "Chemotherapy", vocabulary_id: "DRG" },
                                    { concept_id: 2, concept_code: "410", concept_name: "Biliary tract", vocabulary_id: "DRG" },
                                    { concept_id: 3, concept_code: "871", concept_name: "Sepsis  w MV", vocabulary_id: "DRG" },
                                    { concept_id: 4, concept_code: "871", concept_name: "sepsis w mv", vocabulary_id: "DRG" }
                                  ])
      end
    end

    let(:lexicon) { ConceptQL::Lexicon.new(lexicon_db) }

    it "counts names that differ only in case or spacing as one name" do
      _(lexicon.code_meanings(lexicon_db, "DRG", %w[410 871 999])).must_equal("410" => [ "Biliary tract", "Chemotherapy" ])
    end

    it "returns nothing without codes" do
      _(lexicon.code_meanings(lexicon_db, "DRG", [])).must_equal({})
    end
  end

  it "gives no warning and no error without a lexicon" do
    _(warnings_for(ConceptQL::Database.new(nil), %w[drg 410])).must_be_nil
  end
end
