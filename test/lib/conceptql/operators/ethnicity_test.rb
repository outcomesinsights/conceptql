# frozen_string_literal: true

require_relative "../../../db_helper"

# ethnicity selects patients by ethnicity_concept_id. An Unknown argument
# selects the patients who have no ethnicity (NULL) or ethnicity concept 0.
#
# The test data has no patient with a NULL ethnicity or ethnicity 0, so the
# test sets them in a transaction that it rolls back.
describe ConceptQL::Operators::Ethnicity do
  def patients(*ethnicities)
    CDB.query([ "ethnicity", *ethnicities ]).query.select_map(:criterion_id).sort
  end

  # The patients table, qualified with its schema. On DuckDB the unqualified
  # name is a view, which cannot be updated.
  def patients_table
    schema = ENV.fetch("SEQUELIZER_SEARCH_PATH").split(",").map { |s| s.strip.to_sym }
                .find { |s| DB.table_exists?(Sequel[s][:patients]) }
    _(schema).wont_be_nil "no schema on the search path has patients"
    Sequel[schema][:patients]
  end

  # Runs statement inside the windows of window and checks the spec's rule for
  # the person operators: each patient who has a window is kept, whatever the
  # dates, the other patients are not, and each record has its window_id.
  def assert_keeps_patients_with_a_window(statement, window)
    selected = CDB.query(statement).query.select_map(:person_id).uniq.sort
    window_people = CDB.query(window).query.select_map(:person_id).uniq.sort
    expected = selected & window_people
    _(expected).wont_be_empty "#{statement.inspect}: no patient has a window"
    _(expected.size).must_be :<, selected.size, "#{statement.inspect}: the window excludes no patient"

    rows = CDB.query([ "window", statement, { "window_table" => window } ]).query.all
    _(rows.map { |r| r[:person_id] }.uniq.sort).must_equal expected
    _(rows.select { |r| r[:window_id].nil? }).must_be_empty
  end

  it "keeps only the patients who have a window, as gender does" do
    assert_keeps_patients_with_a_window(%w[gender Male], [ "icd9", "412" ])
    assert_keeps_patients_with_a_window(%w[ethnicity Hispanic], %w[gender Male])
  end

  it "selects the patients with no ethnicity or ethnicity concept 0 for Unknown" do
    skip "Spark cannot update the test data" if DB.database_type.to_sym == :spark

    hispanic = patients("Hispanic")
    not_hispanic = patients("Not Hispanic")
    _(hispanic).wont_be_empty
    _(not_hispanic.size).must_be :>=, 2
    _(DB[:patients].where(Sequel.|({ ethnicity_concept_id: nil }, { ethnicity_concept_id: 0 })).count).must_equal 0

    DB.transaction(rollback: :always) do
      no_ethnicity, ethnicity_zero = not_hispanic.first(2)
      DB[patients_table].where(id: no_ethnicity).update(ethnicity_concept_id: nil)
      DB[patients_table].where(id: ethnicity_zero).update(ethnicity_concept_id: 0)

      _(patients("Unknown")).must_equal [ no_ethnicity, ethnicity_zero ].sort
      _(patients("Hispanic", "Unknown")).must_equal (hispanic + [ no_ethnicity, ethnicity_zero ]).sort
    end
  end
end
