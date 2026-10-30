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
        _(cdb.query(statement).validation_errors).must_equal("invalid" => [ [ "invalid operator", "" ] ])
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
      _(cdb.query(%w[nope_op 412]).validation_errors).must_equal("nope_op" => [ [ "invalid operator", "nope_op" ] ])
    end
  end
end
