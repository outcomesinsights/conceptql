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

# With at_least or within, occurrence's timed query can pass along several
# records of one person: in test/results/gdm/occurrence, person 82 has 41
# rows in results_4_icd9_within_60d.json. So only the plain query gives one
# event per patient (bead conceptql-vsqm). t_shank writes this value into
# each export. No live database: the mock never answers a query.
describe "occurrence events_per_patient" do
  let(:cdb) { ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm_wide) }

  def events_per_patient(statement)
    cdb.query(statement).events_per_patient
  end

  {
    "at_least" => { at_least: "30d" },
    "within" => { within: "60d" },
    "at_least and within" => { at_least: "30d", within: "1y" },
    "within and group_by_date" => { within: "60d", group_by_date: true }
  }.each do |desc, opts|
    it "is multiple with #{desc}" do
      _(events_per_patient([ "occurrence", 2, %w[icd9 412], opts ])).must_equal :multiple
    end
  end

  {
    "no options" => {},
    "a blank at_least and within" => { at_least: "", within: " " },
    "group_by_date" => { group_by_date: true }
  }.each do |desc, opts|
    it "is single with #{desc}" do
      _(events_per_patient([ "occurrence", 2, %w[icd9 412], opts ])).must_equal :single
    end
  end

  %w[first last].each do |name|
    it "is single for #{name}" do
      _(events_per_patient([ name, %w[icd9 412] ])).must_equal :single
    end
  end
end
