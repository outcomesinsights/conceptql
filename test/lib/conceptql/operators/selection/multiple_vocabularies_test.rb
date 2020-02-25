require_relative "../../../../helper"
require "conceptql"

describe ConceptQL::Operators::Selection::MultipleVocabularies do
  it "should appear for both GDM" do
    _(ConceptQL::Operators.operators[:gdm]["cpt_or_hcpcs"]).must_equal ConceptQL::Operators::Selection::MultipleVocabularies
  end

  it "should produce correct SQL under gdm" do
    cdb = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
    sql_matches(cdb.query(["cpt_or_hcpcs", "99214"]).sql, %Q{(("vocabulary_id" IN ('CPT4', 'HCPCS')) AND})
  end

  it "should use #unionize when unioned with other vocabularies" do
    cdb = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
    q = cdb.query(["union", ["cpt_or_hcpcs", "99214"], ["icd9", "412"]])
    sql_matches(q.sql, %Q{((("vocabulary_id" IN ('CPT4', 'HCPCS')) AND })
    sql_doesnt_match(q.sql, "UNION")
  end


  it "should read operators from a custom file" do
    assert_empty(ConceptQL::Operators::Selection::MultipleVocabularies.get_multiple_vocabularies.select do |key, row|
      row.first[:operator] == "test"
    end)
    Tempfile.create("blah.csv") do |f|
      CSV(f) do |csv|
        csv << %w(operator vocabulary_id domain)
        csv << %w(test test_id test_domain)
      end
      f.rewind
      ConceptQL.stub(:custom_multiple_vocabularies_file_path, Pathname.new(f.path)) do
        refute_empty(ConceptQL::Operators::Selection::MultipleVocabularies.get_multiple_vocabularies.select do |key, row|
          row.first[:operator] == "test"
        end)
      end
    end
    assert_empty(ConceptQL::Operators::Selection::MultipleVocabularies.get_multiple_vocabularies.select do |key, row|
      row.first[:operator] == "test"
    end)
  end
end
