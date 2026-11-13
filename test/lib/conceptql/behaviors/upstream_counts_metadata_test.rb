# frozen_string_literal: true

require_relative "../../../helper"

# The upstreams facet of ConceptQL.metadata says how many positional
# upstreams each operator takes: a statement with n positional upstreams
# validates with no upstream-count error exactly when n is in the range of
# the facet's value (upstream_ranges). Before, the metadata said it with
# min_upstreams and max_upstreams, which always had the same value, so union,
# first, last, co_reported and occurrence served 99/99, person and death
# served 1/1, and trim_date_end and trim_date_start served 1/1 (bead
# conceptql-jwsv.1). Bead conceptql-9h85 moved this test to the facet.
#
# The operators whose operands are the left and right options, and read, take
# no positional upstream. Ryan ruled on 2026-11-03 that a positional upstream
# on them is a validation error, because they ignored it.
#
# occurrence, first and last use only their first upstream, so a second one
# was dropped with no error. Ryan ruled on 2026-11-03 that they take exactly
# one upstream, so they serve "one" (bead conceptql-pqy5). Before, 1/99.
#
# union and co_reported serve "two_or_more", but one upstream gives only a
# warning, not an error.
# No database: Database.new(nil) decides which operators are published.
describe "upstream counts in ConceptQL.metadata" do
  # The numbers of positional upstreams that each value of the upstreams
  # facet accepts with no upstream-count error
  let(:upstream_ranges) do
    {
      "none" => 0..0,
      "left_right" => 0..0,
      "none_or_one" => 0..1,
      "one" => 1..1,
      "one_or_more" => 1..,
      "two_or_more" => 1..
    }
  end

  let(:cdb) { ConceptQL::Database.new(nil, data_model: :gdm) }
  let(:operators_metadata) { ConceptQL.metadata(cdb)[:operators] }
  let(:upstream_count_errors) { [ "has upstreams", "has multiple upstreams", "has no upstream" ] }
  let(:left_right_operators) do
    %w[after any_overlap before contains during equal except filter match person_filter trim_date_end trim_date_start]
  end

  def query_with(name, count)
    cdb.query([ name ] + Array.new(count) { [ "icd9", "412" ] })
  end

  def upstream_count_error?(name, count)
    errors = by_operator(query_with(name, count).errors)
    errors.fetch(name, []).any? { |message, *| upstream_count_errors.include?(message) }
  end

  def upstreams_in_metadata(name)
    operators_metadata.fetch(name).fetch(:upstreams)
  end

  it "publishes all 119 operators" do
    _(operators_metadata.size).must_equal 119
  end

  it "matches what validation accepts for every published operator" do
    operators_metadata.each_key do |name|
      range = upstream_ranges.fetch(upstreams_in_metadata(name))
      (0..3).each do |n|
        _(!upstream_count_error?(name, n)).must_equal range.cover?(n), "#{name} with #{n} positional upstreams"
      end
    end
  end

  it "warns about one upstream on each operator that serves two_or_more" do
    names = operators_metadata.select { |_name, metadata| metadata[:upstreams] == "two_or_more" }.keys
    _(names.sort).must_equal %w[co_reported union]
    names.each do |name|
      warnings = by_operator(query_with(name, 1).warnings)
      _(warnings.fetch(name)).must_equal [ [ ConceptQL::Operators::Operator::ONE_UPSTREAM ] ], name
    end
  end

  {
    "union" => "two_or_more",
    "first" => "one",
    "last" => "one",
    "co_reported" => "two_or_more",
    "occurrence" => "one",
    "person" => "none_or_one",
    "death" => "none_or_one",
    "episode" => "one",
    "icd9cm" => "none"
  }.each do |name, expected|
    it "serves #{expected} for #{name}" do
      _(upstreams_in_metadata(name)).must_equal expected
    end
  end

  it "serves none for read and left_right for each operator whose operands are the left and right options" do
    _(upstreams_in_metadata("read")).must_equal "none"
    left_right_operators.each do |name|
      _(upstreams_in_metadata(name)).must_equal "left_right", name
    end
  end

  it "reports a positional upstream on a left/right operator as an error" do
    statement = [ "before", [ "icd9", "412" ], { left: [ "icd9", "412" ], right: [ "icd9", "401.9" ] } ]
    errors = by_operator(cdb.query(statement).errors)
    _(errors).must_equal({ "before" => [ [ "has upstreams", [ "icd9" ] ] ] })
  end

  it "accepts the same statement without the positional upstream" do
    statement = [ "before", { left: [ "icd9", "412" ], right: [ "icd9", "401.9" ] } ]
    _(by_operator(cdb.query(statement).errors)).must_be_empty
  end

  {
    "occurrence" => [ "occurrence", 2 ],
    "first" => [ "first" ],
    "last" => [ "last" ]
  }.each do |name, head|
    it "reports a second upstream on #{name} as an error" do
      statement = head + [ [ "icd9", "412" ], [ "icd9", "401.9" ] ]
      errors = by_operator(cdb.query(statement).errors)
      _(errors).must_equal({ name => [ [ "has multiple upstreams", %w[icd9 icd9] ] ] })
    end

    it "accepts one upstream on #{name}" do
      statement = head + [ [ "icd9", "412" ] ]
      _(by_operator(cdb.query(statement).errors)).must_be_empty
    end
  end

  it "reports a positional upstream on read as an error" do
    errors = by_operator(cdb.query([ "read", [ "icd9", "412" ], "H33" ]).errors)
    _(errors.fetch("read")).must_equal [ [ "has upstreams", [ "icd9" ] ] ]
  end
end
