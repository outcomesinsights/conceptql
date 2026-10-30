# frozen_string_literal: true

require_relative "../../../db_helper"

# The uuid joins person_id, criterion_id, criterion_table, start_date and
# end_date with "/". A NULL part used to make the whole uuid NULL, and a NULL
# uuid matches nothing, so trim_date with join_columns uuid passed such a
# window through untrimmed. A NULL part is now an empty string (bead
# conceptql-18n).
describe "uuid" do
  def rdbms
    ConceptQL::Rdbms.generate(DB.database_type)
  end

  def uuid_of(person_id:, criterion_id:, criterion_table:, start_date:, end_date:)
    DB.select(
      Sequel.cast(person_id, :Bigint).as(:person_id),
      Sequel.cast(criterion_id, :Bigint).as(:criterion_id),
      Sequel.cast(criterion_table, String).as(:criterion_table),
      Sequel.cast(start_date, Date).as(:start_date),
      Sequel.cast(end_date, Date).as(:end_date)
    ).from_self.select(rdbms.uuid.as(:uuid)).single_value
  end

  it "joins the parts with a slash" do
    _(uuid_of(person_id: 1, criterion_id: 2, criterion_table: "observations",
              start_date: "2008-03-10", end_date: "2008-03-21"))
      .must_equal "1/2/observations/2008-03-10/2008-03-21"
  end

  it "gives a NULL part as an empty string" do
    _(uuid_of(person_id: 1, criterion_id: nil, criterion_table: "observations",
              start_date: "2008-03-10", end_date: nil))
      .must_equal "1//observations/2008-03-10/"
    _(uuid_of(person_id: nil, criterion_id: nil, criterion_table: nil, start_date: nil, end_date: nil))
      .must_equal "////"
  end

  # The real consequence: an event with no end_date. The fixture has none, so
  # the test copies an event with a NULL end_date into its table, and rolls
  # the copy back.
  it "lets trim_date_end with join_columns uuid match an event with no end_date" do
    skip "Spark reads parquet files, so it cannot roll the copy back" if DB.database_type.to_sym == :spark

    events = [ "icd9", "412", { uuid: true } ]
    earlier = [ "time_window", events, { start: "-30d", end: "-30d" } ]
    statement = [ "trim_date_end", { left: events, right: earlier, join_columns: [ :uuid ] } ]

    DB.transaction(rollback: :always) do
      event = CDB.query(events).query.order(:criterion_id).first
      # On DuckDB, the search path is a set of views, so insert into the
      # table of the first schema that has it, as a search path finds it.
      schema = ENV.fetch("SEQUELIZER_SEARCH_PATH").split(",").map(&:strip).find do |name|
        DB.table_exists?(Sequel[name.to_sym][event[:criterion_table].to_sym])
      end
      table = DB[Sequel[schema.to_sym][event[:criterion_table].to_sym]]
      copy = table.where(id: event[:criterion_id]).first
      copy_id = table.max(:id) + 1
      table.insert(copy.merge(id: copy_id, end_date: nil))

      open = CDB.query(events).query.all.select { |row| row[:criterion_id] == copy_id }
      _(open.map { |row| row[:end_date] }).must_equal [ nil ]

      # Each event's own uuid has a right row 30 days earlier, so every event
      # is dropped, the copy too.
      _(CDB.query(statement).query.all).must_be_empty
      _(open.first[:uuid]).wont_be_nil
    end
  end
end
