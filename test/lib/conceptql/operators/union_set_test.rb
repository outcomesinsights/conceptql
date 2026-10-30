# frozen_string_literal: true

require_relative "../../../db_helper"

# Every stream is a set (seed conceptql-0eb, bead conceptql-jib): a row that
# arrives from two upstreams of a union comes out once.
describe ConceptQL::Operators::Union do
  def rows(statement)
    CDB.query(statement).query.from_self.order(*%i[person_id criterion_id start_date]).all
  end

  def counts(statement)
    CDB.query(statement).query.from_self
       .select_group(:criterion_domain)
       .select_append { Sequel.function(:count, 1).as(:rows) }
       .select_append { count(:person_id).distinct.as(:n) }
       .to_h { |h| [ h.delete(:criterion_domain).to_sym, h ] }
  end

  let(:statement) { [ "union", [ "first", %w[icd9 412] ], %w[icd9 412] ] }

  it "returns each row of overlapping inputs once" do
    alone = rows(%w[icd9 412])

    _(alone.length).must_equal 48
    _(rows(statement)).must_equal alone
  end

  it "annotates a union of overlapping inputs with the counts of its rows" do
    skip "Spark does not run locally" if DB.database_type.to_sym == :spark

    _(CDB.query(statement).annotate.last[:annotation][:counts]).must_equal counts(%w[icd9 412])
  end
end
