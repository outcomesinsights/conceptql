require_relative 'db_helper'
require_relative 'db'
require_relative '../lib/conceptql/query'
require_relative '../lib/conceptql/database'

describe ConceptQL::Operators do
  let(:cdb) do
    ConceptQL::Database.new(DB)
  end

  describe "when tables aren't available" do

    it "should not blow up" do
      seq_db = Sequel.connect(DB.opts.merge(search_path: 'bad_path'))
      begin
        save_lexicon = ENV["LEXICON_URL"]
        ENV["LEXICON_URL"] = nil
        db = ConceptQL::Database.new(seq_db)
        query = db.query(["union",["cpt", "00000", "99213"],["icd9", "000.00", "412"]])
        query.scope_annotate(skip_counts: true).must_equal(
          {:errors=>{},
          :warnings=>{},
          :counts=>{"cpt"=>{:procedure_occurrence=>{:rows=>0, :n=>0}},
                    "icd9"=>{:condition_occurrence=>{:rows=>0, :n=>0}},
                    "union"=>{:procedure_occurrence=>{:rows=>0, :n=>0}, :condition_occurrence=>{:rows=>0, :n=>0}}}}
        )
      ensure
        ENV["LEXICON_URL"] = save_lexicon
      end
    end

    it "should still report if codes aren't properly formatted" do
      seq_db = Sequel.connect(DB.opts.merge(search_path: 'bad_path'))
      db = ConceptQL::Database.new(seq_db)
      query = db.query(["union",["cpt","0000"],["icd9", "00.00"]])
      query.scope_annotate(skip_counts: true).must_equal(
        {:errors=>{},
         :warnings=>{"cpt"=>[["improperly formatted code", "0000"]], "icd9"=>[["improperly formatted code", "00.00"]]},
         :counts=>{"cpt"=>{:procedure_occurrence=>{:rows=>0, :n=>0}},
                   "icd9"=>{:condition_occurrence=>{:rows=>0, :n=>0}},
                   "union"=>{:procedure_occurrence=>{:rows=>0, :n=>0}, :condition_occurrence=>{:rows=>0, :n=>0}}}}
      )
    end
  end
end

