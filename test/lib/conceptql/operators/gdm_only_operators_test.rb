# frozen_string_literal: true

require_relative "../../../helper"

# The provenance and utilization operators read GDM's provenance vocabularies,
# which omopv4_plus does not have. They register for gdm and gdm_wide only, so
# on omopv4_plus a statement that uses one fails validation as an invalid
# operator instead of raising NoMethodError (conceptql-myp). No live database:
# the mock never answers a query.
describe "operators that only GDM data models have" do
  gdm_only = {
    "provenance" => ConceptQL::Operators::Provenance,
    "one_in_two_out" => ConceptQL::Operators::OneInTwoOut,
    "hospitalization" => ConceptQL::Operators::Hospitalization,
    "hospice" => ConceptQL::Operators::Hospice,
    "snf" => ConceptQL::Operators::Snf
  }

  statements = {
    "provenance" => [ "provenance", [ "icd9", "250.00" ], "inpatient" ],
    "one_in_two_out" => [ "one_in_two_out", [ "icd9", "250.00" ] ],
    "hospitalization" => [ "hospitalization" ],
    "hospice" => [ "hospice" ],
    "snf" => [ "snf" ]
  }

  def cdb_for(data_model)
    ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: data_model)
  end

  it "covers every operator that reads the provenance vocabularies" do
    readers = ObjectSpace.each_object(Class).select do |klass|
      klass < ConceptQL::Operators::Operator &&
        (klass < ConceptQL::Provenanceable || klass < ConceptQL::Behaviors::Utilizable)
    end

    _(readers.sort_by(&:name)).must_equal gdm_only.values.sort_by(&:name)
  end

  %i[gdm gdm_wide].each do |data_model|
    it "registers them for #{data_model}" do
      operators = cdb_for(data_model).operators

      gdm_only.each do |name, klass|
        _(operators[name]).must_equal klass
      end
    end
  end

  it "does not register them for omopv4_plus" do
    operators = cdb_for(:omopv4_plus).operators

    gdm_only.each_key do |name|
      _(operators).wont_include name
    end
  end

  it "leaves them out of the omopv4_plus metadata" do
    metadata = ConceptQL.metadata(cdb_for(:omopv4_plus))[:operators]

    gdm_only.each_key do |name|
      _(metadata).wont_include name
    end
  end

  statements.each do |name, statement|
    it "makes #{name} an invalid operator on omopv4_plus" do
      query = cdb_for(:omopv4_plus).query(statement)
      operator = query.operator

      _(operator).must_be_instance_of ConceptQL::Operators::Invalid
      _(operator.valid?(query.db)).must_equal false
      _(operator.errors).must_equal [ [ "invalid operator", name ] ]
      _(query.annotate.last[:annotation][:errors]).must_equal [ [ "invalid operator", name ] ]
    end
  end
end
