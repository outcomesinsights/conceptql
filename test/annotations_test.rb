require_relative 'db_helper'
require_relative 'db'
require_relative '../lib/conceptql/query'
require_relative '../lib/conceptql/database'

describe ConceptQL::Operators do
  let(:database) do
    Sequel.mock(host: :postgres)
  end

  let(:cdb) do
    ConceptQL::Database.new(db)
  end

  it "should properly detect a codeset" do
    query = db.query(["union",["cpt","00000"],["icd9", "000.00"]])
    query.analysis[:is_code_set].must_equal true
    query = db.query([""])
  end



  it "should validate source codes" do
    query.scope_annotate.must_equal({:errors=>{},
                                     :warnings=>{"cpt"=>[["unknown concept code", "00000"]], "icd9"=>[["unknown source code", "000.00"]]},
                                     :counts=>{"cpt"=>{:procedure_occurrence=>{:rows=>0, :n=>0}},
                                               "icd9"=>{:condition_occurrence=>{:rows=>0, :n=>0}},
                                               "union"=>{:procedure_occurrence=>{:rows=>0, :n=>0},
                                                         :condition_occurrence=>{:rows=>0, :n=>0}}}, :operators=>["cpt", "icd9", "union"]})
  end

  describe "when tables aren't available" do

    it "should not blow up" do
      seq_db = Sequel.connect(DB.opts.merge(search_path: 'bad_path'))
      db = ConceptQL::Database.new(seq_db)
      query = db.query(["union",["cpt","00000"],["icd9", "000.00"]])
      query.scope_annotate(skip_counts: true).must_equal(
        {:errors=>{},
         :warnings=>{},
         :counts=>{"cpt"=>{:procedure_occurrence=>{:rows=>0, :n=>0}},
                   "icd9"=>{:condition_occurrence=>{:rows=>0, :n=>0}},
                   "union"=>{:procedure_occurrence=>{:rows=>0, :n=>0}, :condition_occurrence=>{:rows=>0, :n=>0}}}, :operators=>["cpt", "icd9", "union"]}
      )
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
                   "union"=>{:procedure_occurrence=>{:rows=>0, :n=>0}, :condition_occurrence=>{:rows=>0, :n=>0}}}, :operators=>["cpt", "icd9", "union"]}
      )
    end
  end
end

