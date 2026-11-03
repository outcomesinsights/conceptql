# frozen_string_literal: true

require_relative "../../../db_helper"

# config/vocabularies.csv had two hidden rows, "Place of Service" and
# "Specialty", whose ids no lexicon has: the lexicons name those vocabularies
# "CMS Place of Service" and "Medicare Specialty" (bead conceptql-sbnw). The
# rows built place_of_service, which compiled to 1 = 0 with no warning, and
# specialty, which read a column that practitioners does not have. Both rows
# are gone. The lexicon's own operators for those vocabularies stay as they were.
describe "the removed vocabulary rows Place of Service and Specialty" do
  # The CTE name ends with a hash of the statement, so two names for one
  # operator give the same SQL apart from that hash.
  def sql_without_cte_hash(statement)
    CDB.query(statement).sql.gsub(/_\h{32}(["`])/, '_HASH\1')
  end

  def errors_of(statement)
    CDB.query(statement).annotate.last[:annotation][:errors]
  end

  it "makes each removed name an invalid operator" do
    [ "place_of_service", "place of service", "specialty", "Specialty" ].each do |name|
      _(CDB.operators).wont_include name.downcase
      _(errors_of([ name, "21" ])).must_equal [ [ "invalid operator", name.downcase ] ]
    end
  end

  it "keeps cms_place_of_service, the lexicon's operator for CMS Place of Service" do
    klass = CDB.operators.fetch("cms_place_of_service")

    _(klass.entry.omopv5_id).must_equal "CMS Place of Service"
    _(klass.entry).must_be :from_lexicon?
    _(klass.entry).wont_be :from_csv?
    # The OHDSI lexicon gives no domain and the GDM lexicon gives "".
    _(klass.entry.domain.to_s).must_be_empty
    _(CDB.query([ "cms_place_of_service", "21" ]).sql).must_match(/["`]clinical_code_vocabulary_id["`] = 'CMS Place of Service'/)
  end

  # A draft algorithm in production names the operator "cms place of service".
  # The lexicon entry's id has spaces, so the Entry keeps it, downcased, as an
  # alias, and the Nodifier downcases the name before it looks up the alias.
  it "resolves the name with spaces to cms_place_of_service, with the same SQL" do
    _(CDB.operators.fetch("cms_place_of_service").aliases).must_include "cms place of service"

    [ "cms place of service", "CMS Place of Service" ].each do |name|
      _(CDB.query([ name, "21" ]).send(:operator)).must_be_instance_of CDB.operators.fetch("cms_place_of_service")
      _(sql_without_cte_hash([ name, "21" ])).must_equal sql_without_cte_hash([ "cms_place_of_service", "21" ])
    end
  end

  it "keeps medicare_specialty, the lexicon's operator for Medicare Specialty" do
    klass = CDB.operators.fetch("medicare_specialty")

    _(klass.entry.omopv5_id).must_equal "Medicare Specialty"
    _(klass.entry).must_be :from_lexicon?
    _(klass.entry).wont_be :from_csv?
    # The OHDSI lexicon gives no domain and the GDM lexicon gives "".
    _(klass.entry.domain.to_s).must_be_empty
    _(CDB.query([ "medicare_specialty", "C0" ]).sql).must_match(/["`]clinical_code_vocabulary_id["`] = 'Medicare Specialty'/)
  end
end
