# frozen_string_literal: true

require_relative "../../../db_helper"

# The gap rule of episode (bead conceptql-d3ln). A record stays in the episode
# while its start_date is no more than gap_of days after the episode's end so
# far, the latest end_date of the episode's earlier records. A NULL end_date
# counts as the record's start_date. Each test reads its own records from a
# temporary view, so the rows are known and the episodes are worked out by hand.
describe "episode gap_of" do
  def view = :episode_gap_test_records

  def records(rows)
    selects = rows.map do |person_id, start_date, end_date|
      DB.select(
        Sequel.cast(person_id, :Bigint).as(:person_id),
        Sequel.cast(person_id, :Bigint).as(:criterion_id),
        Sequel.cast("clinical_codes", String).as(:criterion_table),
        Sequel.cast("condition_occurrence", String).as(:criterion_domain),
        Sequel.cast(start_date, Date).as(:start_date),
        Sequel.cast(end_date, Date).as(:end_date),
        Sequel.cast(nil, String).as(:source_value),
        Sequel.cast(nil, String).as(:source_vocabulary_id),
        Sequel.cast(nil, String).as(:label),
        Sequel.cast("default", String).as(:column_family)
      )
    end
    selects.inject { |all, one| all.union(one, all: true, from_self: false) }
  end

  # [person_id, start_date, end_date] of each episode, in order.
  def episodes(rows, gap_of)
    DB.create_view(view, records(rows), temp: true, replace: true)
    statement = [ "episode", [ "from", view.to_s, { "query_cols" => ConceptQL::Scope::DEFAULT_COLUMNS.keys } ],
                  { "gap_of" => gap_of } ]
    CDB.query(statement).query.from_self.order(:person_id, :start_date)
       .select_map(%i[person_id start_date end_date])
       .map { |person_id, start_date, end_date| [ person_id.to_i, start_date.to_date.iso8601, end_date.to_date.iso8601 ] }
  ensure
    DB.drop_view(view, if_exists: true)
  end

  # The probe of the bead: the second record starts inside the first and ends
  # after it. It is one episode whatever the gap.
  probe = [ [ 1, "2020-01-01", "2020-01-10" ], [ 1, "2020-01-05", "2020-03-01" ] ]

  [ 0, 30 ].each do |gap_of|
    it "merges a record that starts inside the episode and ends after it, with gap_of #{gap_of}" do
      _(episodes(probe, gap_of)).must_equal [ [ 1, "2020-01-01", "2020-03-01" ] ]
    end
  end

  it "keeps a record that starts exactly gap_of days after the episode's end" do
    rows = [ [ 2, "2020-01-01", "2020-01-10" ], [ 2, "2020-02-09", "2020-02-20" ] ]

    _(episodes(rows, 30)).must_equal [ [ 2, "2020-01-01", "2020-02-20" ] ]
  end

  it "starts a new episode with a record that starts gap_of + 1 days after the episode's end" do
    rows = [ [ 3, "2020-01-01", "2020-01-10" ], [ 3, "2020-02-10", "2020-02-20" ] ]

    _(episodes(rows, 30)).must_equal [ [ 3, "2020-01-01", "2020-01-10" ], [ 3, "2020-02-10", "2020-02-20" ] ]
  end

  it "starts a new episode with gap_of 0 when a record starts the day after the episode's end" do
    rows = [ [ 4, "2020-01-01", "2020-01-10" ], [ 4, "2020-01-10", "2020-01-15" ], [ 4, "2020-01-16", "2020-01-20" ] ]

    _(episodes(rows, 0)).must_equal [ [ 4, "2020-01-01", "2020-01-15" ], [ 4, "2020-01-16", "2020-01-20" ] ]
  end

  it "measures the gap from the latest end so far, not from the previous record's end" do
    rows = [ [ 5, "2020-01-01", "2020-03-01" ], [ 5, "2020-01-05", "2020-01-10" ], [ 5, "2020-03-01", "2020-03-31" ],
             [ 5, "2020-04-01", "2020-04-02" ] ]

    _(episodes(rows, 0)).must_equal [ [ 5, "2020-01-01", "2020-03-31" ], [ 5, "2020-04-01", "2020-04-02" ] ]
  end

  it "counts a NULL end_date as the start_date" do
    rows = [ [ 6, "2020-03-01", nil ], [ 6, "2020-03-06", "2020-03-20" ],
             [ 7, "2020-03-01", nil ], [ 7, "2020-03-07", "2020-03-20" ] ]

    _(episodes(rows, 5)).must_equal [ [ 6, "2020-03-01", "2020-03-20" ],
                                      [ 7, "2020-03-01", "2020-03-01" ], [ 7, "2020-03-07", "2020-03-20" ] ]
  end

  it "keeps the records of two people apart" do
    rows = [ [ 8, "2020-01-01", "2020-01-31" ], [ 9, "2020-01-15", "2020-02-15" ], [ 9, "2020-02-10", "2020-02-12" ] ]

    _(episodes(rows, 30)).must_equal [ [ 8, "2020-01-01", "2020-01-31" ], [ 9, "2020-01-15", "2020-02-15" ] ]
  end
end
