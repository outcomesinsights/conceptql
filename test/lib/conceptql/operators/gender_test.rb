require_relative "../../../helper"

describe ConceptQL::Operators::Gender do
  it "be present in list of operators" do
    _(ConceptQL::Operators.operators[:omopv4_plus]["gender"]).must_equal ConceptQL::Operators::Gender
  end

  describe "under gdm" do
    let(:db) do
      ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
    end

    it "should work with male" do
      check_sequel(db.query(["gender", "male"]), :gender, :with_male)
    end

    it "should work with female" do
      check_sequel(db.query(["gender", "female"]), :gender, :with_female)
    end

    it "should work with unknown" do
      check_sequel(db.query(["gender", "unknown"]), :gender, :with_unknown)
    end

    it "should work with all" do
      check_sequel(db.query(["gender", "male", "female", "unknown"]), :gender, :with_all)
    end
  end
end

