# frozen_string_literal: true

require_relative "../../../helper"

# ConceptQL.metadata says how many positional upstreams each operator takes:
# a statement with n positional upstreams validates with no upstream-count
# error exactly when min_upstreams <= n <= max_upstreams (99 means no limit).
# Before, min_upstreams always equalled max_upstreams, so union, first, last,
# co_reported and occurrence served 99/99, person and death served 1/1, and
# trim_date_end and trim_date_start served 1/1 (bead conceptql-jwsv.1).
#
# The operators whose operands are the left and right options, and read, take
# no positional upstream. Ryan ruled on 2026-11-03 that a positional upstream
# on them is a validation error, because they ignored it.
# No database: Database.new(nil) decides which operators are published.
describe "upstream counts in ConceptQL.metadata" do
  let(:cdb) { ConceptQL::Database.new(nil, data_model: :gdm) }
  let(:operators_metadata) { ConceptQL.metadata(cdb)[:operators] }
  let(:upstream_count_errors) { [ "has upstreams", "has multiple upstreams", "has no upstream" ] }
  let(:left_right_operators) do
    %w[after any_overlap before contains during equal except filter match person_filter trim_date_end trim_date_start]
  end

  def upstream_count_error?(name, count)
    statement = [ name ] + Array.new(count) { [ "icd9", "412" ] }
    errors = cdb.query(statement).scope_annotate(skip_counts: true)[:errors]
    errors.fetch(name, []).any? { |message, *| upstream_count_errors.include?(message) }
  end

  def counts_in_metadata(name)
    operators_metadata.fetch(name).values_at(:min_upstreams, :max_upstreams)
  end

  it "publishes all 119 operators" do
    _(operators_metadata.size).must_equal 119
  end

  it "matches what validation accepts for every published operator" do
    operators_metadata.each_key do |name|
      min, max = counts_in_metadata(name)
      (0..3).each do |n|
        in_metadata = n >= min && (max == 99 || n <= max)
        _(!upstream_count_error?(name, n)).must_equal in_metadata, "#{name} with #{n} positional upstreams"
      end
    end
  end

  {
    "union" => [ 1, 99 ],
    "first" => [ 1, 99 ],
    "last" => [ 1, 99 ],
    "co_reported" => [ 1, 99 ],
    "occurrence" => [ 1, 99 ],
    "person" => [ 0, 1 ],
    "death" => [ 0, 1 ],
    "episode" => [ 1, 1 ],
    "icd9cm" => [ 0, 0 ]
  }.each do |name, expected|
    it "serves #{expected.join('/')} for #{name}" do
      _(counts_in_metadata(name)).must_equal expected
    end
  end

  it "serves 0/0 for read and for each operator whose operands are the left and right options" do
    (left_right_operators + [ "read" ]).each do |name|
      _(counts_in_metadata(name)).must_equal [ 0, 0 ], name
    end
  end

  it "reports a positional upstream on a left/right operator as an error" do
    statement = [ "before", [ "icd9", "412" ], { left: [ "icd9", "412" ], right: [ "icd9", "401.9" ] } ]
    errors = cdb.query(statement).scope_annotate(skip_counts: true)[:errors]
    _(errors).must_equal("before" => [ [ "has upstreams", [ "icd9" ] ] ])
  end

  it "accepts the same statement without the positional upstream" do
    statement = [ "before", { left: [ "icd9", "412" ], right: [ "icd9", "401.9" ] } ]
    _(cdb.query(statement).scope_annotate(skip_counts: true)[:errors].to_h).must_be_empty
  end

  it "reports a positional upstream on read as an error" do
    errors = cdb.query([ "read", [ "icd9", "412" ], "H33" ]).scope_annotate(skip_counts: true)[:errors]
    _(errors.fetch("read")).must_equal [ [ "has upstreams", [ "icd9" ] ] ]
  end
end
