require_relative "../../../helper"

describe ConceptQL::Operators::Selection::Gender do
  it "be present in list of operators" do
    _(ConceptQL::Operators.operators[:gdm]["gender"]).must_equal ConceptQL::Operators::Selection::Gender
  end

  describe "under gdm" do
    let(:cdb) do
      ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
    end

    it "should work with male" do
      sql_matches(cdb.query(["gender", "male"]).sql, '"ancestor_id" IN (8507)', "patients_cql_view")
    end

    it "should work with female" do
      sql_matches(cdb.query(["gender", "female"]).sql, '"ancestor_id" IN (8532)', "patients_cql_view")
    end

    it "should work with unknown" do
      sql_matches(cdb.query(["gender", "unknown"]).sql, '"gender_concept_id" IS NULL', '"gender_concept_id" NOT IN')
    end

    it "should work with all" do
      sql_matches(cdb.query(["gender", "male", "female", "unknown"]).sql, '"gender_concept_id" IS NULL', '"gender_concept_id" NOT IN', '"gender_concept_id" IN')
    end
  end
end

