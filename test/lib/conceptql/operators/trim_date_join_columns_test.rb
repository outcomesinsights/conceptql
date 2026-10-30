# frozen_string_literal: true

require_relative "../../../db_helper"

# Without compare_all, trim_date_end trims a left row by the first right row
# (trim_date_start: the last right row) of the left row's person AND
# join_columns values. compare_all groups the right rows the same way. Before
# bead conceptql-18n, the first right row was chosen per person only, so a
# left row whose join values differed from that row's passed through
# untrimmed.
describe "trim_date_start and trim_date_end with join_columns, without compare_all" do
  def rows(statement)
    CDB.query(statement).query.all
  end

  def key_columns
    %i[person_id criterion_id criterion_table criterion_domain start_date end_date]
  end

  def keys(rows)
    rows.map { |row| row.values_at(*key_columns) }.sort_by { |key| key.map(&:to_s) }
  end

  events = [ "icd9", "412", { uuid: true } ]

  def dates_by_uuid(result)
    result.map { |row| [ row[:uuid], row[:start_date], row[:end_date] ] }.sort_by { |key| key.map(&:to_s) }
  end

  # The t_shank export engine trims each window by its own event: the window
  # and the event share a uuid.
  it "trim_date_end trims each window by the event with its uuid" do
    windows = [ "time_window", events, { start: "-60d", end: "30d" } ]
    result = rows([ "trim_date_end", { left: windows, right: events, join_columns: [ :uuid ] } ])

    expected = rows(events).uniq.map { |row| [ row[:uuid], row[:start_date] - 60, row[:start_date] ] }
    _(expected.size).must_be :>, rows(events).map { |row| row[:person_id] }.uniq.size
    _(dates_by_uuid(result)).must_equal(expected.sort_by { |key| key.map(&:to_s) })
  end

  it "trim_date_start trims each window by the event with its uuid" do
    windows = [ "time_window", events, { start: "-30d", end: "60d" } ]
    result = rows([ "trim_date_start", { left: windows, right: events, join_columns: [ :uuid ] } ])

    expected = rows(events).uniq.map { |row| [ row[:uuid], row[:end_date], row[:end_date] + 60 ] }
    _(dates_by_uuid(result)).must_equal(expected.sort_by { |key| key.map(&:to_s) })
  end

  # A right row that starts before its left row drops the left row, so a
  # window with a right row of its own uuid that fails is dropped.
  it "drops every event when the event with its uuid fails the check" do
    earlier = [ "time_window", events, { start: "-30d", end: "-30d" } ]
    later = [ "time_window", events, { start: "30d", end: "30d" } ]

    _(rows([ "trim_date_end", { left: events, right: earlier, join_columns: [ :uuid ] } ])).must_be_empty
    _(rows([ "trim_date_start", { left: events, right: later, join_columns: [ :uuid ] } ])).must_be_empty
  end

  # The same rules, computed in Ruby. The first (trim_date_end) or last
  # (trim_date_start) right row of each person and join value, ordered by
  # start_date and then criterion_id, as the occurrence operator orders them.
  def expected(left_rows, right_rows, operator, join_column)
    groups = right_rows.uniq.group_by { |row| row.values_at(:person_id, join_column) }
    chosen = groups.transform_values do |group|
      ordered = group.sort_by { |row| [ row[:start_date], row[:criterion_id] ] }
      operator == "trim_date_end" ? ordered.first : ordered.last
    end

    left_rows.uniq.filter_map do |row|
      right = chosen[row.values_at(:person_id, join_column)]
      next row unless right

      if operator == "trim_date_end"
        next unless row[:start_date] <= right[:start_date]

        row.merge(end_date: [ row[:end_date], right[:start_date] ].min)
      else
        next unless row[:end_date] >= right[:end_date]

        row.merge(start_date: [ row[:start_date], right[:end_date] ].max)
      end
    end
  end

  %w[trim_date_end trim_date_start].each do |operator|
    it "#{operator} with join_columns gives the rows that the rules give" do
      both = [ "union", [ "icd9", "412" ], [ "cpt", "99214" ] ]
      windows = [ "time_window", both, { start: "-90d", end: "90d" } ]
      result = rows([ operator, { left: windows, right: both, join_columns: [ :criterion_domain ] } ])

      want = expected(rows(windows), rows(both), operator, :criterion_domain)
      _(want.size).must_be :>, 0
      _(keys(result)).must_equal keys(want)
    end
  end
end
