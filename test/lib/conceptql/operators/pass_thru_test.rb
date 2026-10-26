# frozen_string_literal: true

require_relative "../../../helper"

# PassThru is only a base class: it supplies domains and query_cols to its
# subclasses and has no query method. It used to register itself, so a
# pass_thru statement got past validation and then raised NoMethodError while
# it built SQL (conceptql-vw7). Now pass_thru is an invalid operator and the
# subclasses register as before. No live database: the mock never answers a
# query.
describe ConceptQL::Operators::PassThru do
  subclasses = {
    "co_reported" => ConceptQL::Operators::CoReported,
    "count" => ConceptQL::Operators::Count,
    "dedup" => ConceptQL::Operators::Dedup,
    "episode" => ConceptQL::Operators::Episode,
    "numeric" => ConceptQL::Operators::Numeric,
    "sum" => ConceptQL::Operators::Sum,
    "time_window" => ConceptQL::Operators::TimeWindow,
    "union" => ConceptQL::Operators::Union
  }

  def cdb_for(data_model)
    ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: data_model)
  end

  it "has exactly the listed subclasses" do
    found = ObjectSpace.each_object(Class).select { |klass| klass < ConceptQL::Operators::PassThru }

    _(found.sort_by(&:name)).must_equal subclasses.values.sort_by(&:name)
  end

  ConceptQL::Operators::STATIC_OPERATORS.each_key do |data_model|
    it "does not register pass_thru for #{data_model}" do
      operators = cdb_for(data_model).operators

      _(operators).wont_include "pass_thru"
      _(operators.values).wont_include ConceptQL::Operators::PassThru
    end

    it "registers every subclass for #{data_model}" do
      operators = cdb_for(data_model).operators

      subclasses.each do |name, klass|
        _(operators[name]).must_equal klass
      end
    end
  end

  it "makes a pass_thru statement an invalid operator" do
    query = cdb_for(:gdm).query([ "pass_thru", [ "icd9", "412" ] ])
    operator = query.operator

    _(operator).must_be_instance_of ConceptQL::Operators::Invalid
    _(operator.valid?(query.db)).must_equal false
    _(operator.errors).must_equal [ [ "invalid operator", "pass_thru" ] ]
    _(query.annotate.last[:annotation][:errors]).must_equal [ [ "invalid operator", "pass_thru" ] ]
  end
end
