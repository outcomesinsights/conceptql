# frozen_string_literal: true

require_relative "../../../helper"
require "conceptql"

# An Invalid operator stands in for an operator that conceptql does not know.
# Its name is the name in the statement. The statement [nil] has no name, so
# it reports under "invalid", as an empty statement does, and not under ""
# (bead conceptql-1ci).
describe ConceptQL::Operators::Invalid do
  let(:cdb) { ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm) }

  [ [ nil ], [ "" ] ].each do |statement|
    describe "for #{statement.inspect}" do
      it "is named invalid" do
        _(cdb.query(statement).operator.operator_name).must_equal "invalid"
      end

      it "reports its error under the key invalid" do
        _(by_operator(cdb.query(statement).validation_errors)).must_equal({ "invalid" => [ [ "invalid operator", "" ] ] })
      end
    end
  end

  describe "for an unknown operator" do
    let(:operator) { cdb.query(%w[nope_op 412]).operator }

    it "is named after it" do
      _(operator.operator_name).must_equal "nope_op"
    end

    it "keeps its arguments when it gives its name" do
      operator.operator_name
      _(operator.arguments).must_equal %w[412]
    end

    it "reports its error under its name" do
      _(by_operator(cdb.query(%w[nope_op 412]).validation_errors)).must_equal({ "nope_op" => [ [ "invalid operator", "nope_op" ] ] })
    end
  end

  # concurrent_within was removed (bead conceptql-ayt2). No production
  # algorithm used it. A statement that names it is an unknown operator.
  describe "for the removed operator concurrent_within" do
    let(:statement) { [ "concurrent_within", [ "icd9", "412" ], [ "cpt", "99214" ], { "start" => "1d" } ] }
    let(:query) { cdb.query(statement) }

    it "is an Invalid operator" do
      _(cdb.operators).wont_include "concurrent_within"
      _(query.operator).must_be_instance_of ConceptQL::Operators::Invalid
    end

    it "reports the invalid-operator error" do
      _(by_operator(query.validation_errors)).must_equal({ "concurrent_within" => [ [ "invalid operator", "concurrent_within" ] ] })
      _(query.annotate.last[:annotation][:errors]).must_equal [ [ "invalid operator", "concurrent_within" ] ]
    end

    it "raises InvalidStatementError from the plain query" do
      error = _ { query.sql }.must_raise ConceptQL::InvalidStatementError
      _(by_operator(error.errors)).must_equal({ "concurrent_within" => [ [ "invalid operator", "concurrent_within" ] ] })
    end
  end
end
