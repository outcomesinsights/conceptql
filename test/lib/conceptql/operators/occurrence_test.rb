# frozen_string_literal: true

require_relative "../../../helper"

# An editor can send a blank at_least or within for an empty field. A blank
# value counts as not set, so it must not select Occurrence's timed query
# (bead conceptql-345). No live database: the mock never answers a query.
describe "occurrence with blank at_least and within" do
  let(:cdb) { ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm_wide) }

  def timed?(opts)
    cdb.query([ "occurrence", 2, %w[icd9 412], opts ]).operator.timed?
  end

  # Each CTE name ends in a random hex suffix
  def masked_sql(statement)
    cdb.query(statement).sql.gsub(/_\h{32}\b/, "_HEX")
  end

  %i[at_least within].each do |name|
    [ nil, "", "  " ].each do |value|
      it "is not timed with #{name} #{value.inspect}" do
        _(timed?(name => value)).must_equal false
      end
    end

    it "is timed with a real #{name}" do
      _(timed?(name => "30d")).must_equal true
    end
  end

  it "is not timed without options" do
    _(timed?({})).must_equal false
  end

  it "gives the plain occurrence SQL for a blank at_least and within" do
    plain = [ "occurrence", 2, %w[icd9 412] ]
    blank = [ "occurrence", 2, %w[icd9 412], { at_least: "", within: " " } ]

    _(masked_sql(blank)).must_equal masked_sql(plain)
  end
end
