# frozen_string_literal: true

require_relative "../../../db_helper"

# With compare_all, trim_date_end and trim_date_start return one row for each
# left row, trimmed by the nearest right row that passes the left row's check:
# for trim_date_end, the earliest start_date on or after the left start_date;
# for trim_date_start, the latest end_date on or before the left end_date. A
# left row with right rows of which none passes is dropped. A left row with no
# right rows passes through unchanged (bead conceptql-x6m, seed conceptql-ysx).
describe "trim_date_start and trim_date_end with compare_all" do
  def key_columns
    %i[person_id criterion_id criterion_table start_date end_date]
  end

  def rows(statement)
    CDB.query(statement).query.all
  end

  def keys(rows)
    rows.map { |row| row.values_at(*key_columns) }.sort_by { |key| key.map(&:to_s) }
  end

  def window(start, finish)
    [ "date_range", { start: start, end: finish } ]
  end

  # One left row for each person: 2008-03-10 to 2008-03-21.
  left = [ "date_range", { start: "2008-03-10", end: "2008-03-21" } ]

  # Right rows for each person: one before the left row, two inside it, and
  # one after it.
  right = [
    "union",
    [ "date_range", { start: "2008-03-01", end: "2008-03-01" } ],
    [ "date_range", { start: "2008-03-17", end: "2008-03-17" } ],
    [ "date_range", { start: "2008-03-19", end: "2008-03-19" } ],
    [ "date_range", { start: "2008-04-01", end: "2008-04-01" } ]
  ]

  def people
    rows([ "date_range", { start: "2008-03-10", end: "2008-03-21" } ]).map { |row| row[:person_id] }.sort
  end

  it "trim_date_end trims each left row once, by the earliest right start_date on or after its start" do
    result = rows([ "trim_date_end", { left: left, right: right, compare_all: true } ])

    _(result.map { |row| row[:person_id] }.sort).must_equal people
    _(result.map { |row| [ row[:start_date], row[:end_date] ] }.uniq)
      .must_equal [ [ Date.new(2008, 3, 10), Date.new(2008, 3, 17) ] ]
  end

  it "trim_date_start trims each left row once, by the latest right end_date on or before its end" do
    result = rows([ "trim_date_start", { left: left, right: right, compare_all: true } ])

    _(result.map { |row| row[:person_id] }.sort).must_equal people
    _(result.map { |row| [ row[:start_date], row[:end_date] ] }.uniq)
      .must_equal [ [ Date.new(2008, 3, 19), Date.new(2008, 3, 21) ] ]
  end

  it "trim_date_end passes a left row through once when every right row starts after it ends" do
    after = [ "union", window("2008-04-01", "2008-04-01"), window("2008-05-01", "2008-05-01") ]
    result = rows([ "trim_date_end", { left: left, right: after, compare_all: true } ])

    _(result.map { |row| row[:person_id] }.sort).must_equal people
    _(result.map { |row| [ row[:start_date], row[:end_date] ] }.uniq)
      .must_equal [ [ Date.new(2008, 3, 10), Date.new(2008, 3, 21) ] ]
  end

  it "trim_date_start passes a left row through once when every right row ends before it starts" do
    before = [ "union", window("2008-01-01", "2008-01-01"), window("2008-02-01", "2008-02-01") ]
    result = rows([ "trim_date_start", { left: left, right: before, compare_all: true } ])

    _(result.map { |row| row[:person_id] }.sort).must_equal people
    _(result.map { |row| [ row[:start_date], row[:end_date] ] }.uniq)
      .must_equal [ [ Date.new(2008, 3, 10), Date.new(2008, 3, 21) ] ]
  end

  it "drops a left row when it has right rows and none of them passes" do
    before = window("2008-03-01", "2008-03-01")
    after = window("2008-04-01", "2008-04-01")

    _(rows([ "trim_date_end", { left: left, right: before, compare_all: true } ])).must_be_empty
    _(rows([ "trim_date_start", { left: left, right: after, compare_all: true } ])).must_be_empty
  end

  it "trim_date_end returns event 523 once, trimmed by the earliest CPT 99214 on or after its start" do
    result = rows([ "trim_date_end", { left: [ "icd9", "412" ], right: [ "cpt", "99214" ], compare_all: true } ])
    mine = result.select { |row| row[:person_id] == 230 && row[:criterion_id] == 523 }

    _(mine.map { |row| row[:end_date] }).must_equal [ Date.new(2008, 3, 17) ]
  end

  # The t_shank export engine trims each window by its own T0: the window and
  # the T0 share a uuid, and join_columns matches them.
  it "trim_date_end with join_columns trims each window by the right row with its uuid" do
    events = [ "icd9", "412", { uuid: true } ]
    windows = [ "time_window", events, { start: "-60d", end: "30d" } ]
    result = rows([ "trim_date_end", { left: windows, right: events, join_columns: [ :uuid ], compare_all: true } ])

    expected = rows(events).uniq.map { |row| [ row[:uuid], row[:start_date] - 60, row[:start_date] ] }.sort
    _(expected.size).must_be :>, 0
    _(result.map { |row| [ row[:uuid], row[:start_date], row[:end_date] ] }.sort).must_equal expected
  end

  # The same rules, computed in Ruby from the left rows and the right rows.
  def expected(left_rows, right_rows, operator)
    by_person = right_rows.group_by { |row| row[:person_id] }
    left_rows.uniq.filter_map do |row|
      candidates = by_person.fetch(row[:person_id], [])
      next row if candidates.empty?

      if operator == "trim_date_end"
        passing = candidates.map { |r| r[:start_date] }.select { |date| date >= row[:start_date] }
        next if passing.empty?

        row.merge(end_date: [ row[:end_date], passing.min ].min)
      else
        passing = candidates.map { |r| r[:end_date] }.select { |date| date <= row[:end_date] }
        next if passing.empty?

        row.merge(start_date: [ row[:start_date], passing.max ].max)
      end
    end
  end

  %w[trim_date_end trim_date_start].each do |operator|
    it "#{operator} with compare_all gives the rows that the rules give" do
      mi = [ "icd9", "412" ]
      visit = [ "cpt", "99214" ]
      result = rows([ operator, { left: mi, right: visit, compare_all: true } ])

      _(result.size).must_be :>, 0
      _(keys(result)).must_equal keys(expected(rows(mi), rows(visit), operator))
    end
  end
end
