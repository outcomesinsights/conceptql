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
