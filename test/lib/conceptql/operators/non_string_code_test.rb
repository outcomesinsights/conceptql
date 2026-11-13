# frozen_string_literal: true

require_relative "../../../db_helper"

# conceptql-uob6: a code given as a JSON number ([["icd9", 412]]) reached
# SQL as a number. Postgres raised "operator does not exist: text = integer",
# and DuckDB raised a conversion error. Now a code that is not a string is an
# error of the statement, on the operator that has the code. The statement
# is invalid and builds no SQL, and annotate does not count it.
describe "a code that is not a string" do
  message = ConceptQL::Operators::Operator::NON_STRING_CODE

  {
    "an Integer code" => [ [ "icd9", 412 ], "icd9", [ 412 ], :condition_occurrence ],
    "a Float code" => [ [ "icd9", 412.0 ], "icd9", [ 412.0 ], :condition_occurrence ],
    "a number among string codes" => [ [ "icd9", "412", 250 ], "icd9", [ 250 ], :condition_occurrence ],
    "a number in a multiple-vocabulary operator" => [ [ "cpt_or_hcpcs", 99214 ], "cpt_or_hcpcs", [ 99214 ],
                                                      :procedure_occurrence ]
  }.each do |name, (statement, operator, details, domain)|
    describe "with #{name}" do
      errors = [ { operator: operator, id: "#{operator}-1", message: message, details: details } ]

      it "is an error of the operator, and the statement is invalid" do
        query = CDB.query(statement)
        _(query.errors).must_equal(errors)
        _(query.valid?).must_equal false
      end

      it "annotates the error with null counts and no format warning" do
        annotation = { id: "#{operator}-1", counts: { domain => { rows: 0, n: 0 } }, errors: [ [ message, *details ] ] }
        _(CDB.query(statement).annotate(skip_counts: true).last[:annotation]).must_equal(annotation)
        _(CDB.query(statement).annotate.last[:annotation]).must_equal(annotation)
      end

      it "builds no SQL and lists no codes" do
        error = _ { CDB.query(statement).sql }.must_raise(ConceptQL::InvalidStatementError)
        _(error.errors).must_equal(errors)
        _(error.message).must_include("  #{operator}: #{message} (#{details.join(', ')})")
        _ { CDB.query(statement).code_list }.must_raise(ConceptQL::InvalidStatementError)
      end
    end
  end

  it "is an error of the vocabulary operator, not of the operator above it" do
    query = CDB.query([ "union", [ "icd9", 412 ], [ "cpt", "99214" ] ])
    _(query.errors).must_equal([ { operator: "icd9", id: "icd9-1", message: message, details: [ 412 ] } ])
  end

  it "leaves a string code valid" do
    query = CDB.query([ "icd9", "412" ])
    _(query.errors).must_equal([])
    _(query.annotate.last[:annotation][:counts][:condition_occurrence][:rows]).must_be :>, 0
    _(query.code_list.map(&:code)).must_equal [ "412" ]
  end
end
