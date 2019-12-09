require_relative "../../../helper"
require "conceptql"

describe ConceptQL::Operators::ProviderFilter do
  describe "in omopv4_plus" do
    let(:dm) { :omopv4_plus }
    it "should find associated_provider_id in condition_occurrence table" do
      db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: dm)
      _(db.query([ "provider_filter", [ "icd9", "412" ], { "specialties" => "38004458" } ]).sql).must_match(/associated_provider_id/)
    end

    it "should find associated_provider_id in procedure_occurrence table" do
      db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: dm)
      _(db.query([ "provider_filter", [ "cpt", "99214" ], { "specialties" => "38004458" } ]).sql).must_match(/associated_provider_id/)
    end

    it "should add no columns in person table" do
      db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: dm)
      _(db.query([ "provider_filter", [ "person" ], { "specialties" => "38004458" } ]).sql).wont_match(/"provider_id"\s*AS/i)
    end

    it "should find associated_provider_id in procedure_occurrence table" do
      db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: dm)
      _(db.query([ "provider_filter", [ "ndc", "0123456789" ], { "specialties" => "38004458" } ]).sql).must_match(/prescribing_provider_id/)
    end
  end
end

