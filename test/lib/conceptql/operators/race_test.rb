# frozen_string_literal: true

require_relative "../../../db_helper"

# race selects patients by race_concept_id. An Unknown argument also selects
# the patients who have no race (NULL) or race concept 0. A race concept ID
# argument selects the more detailed races in config/race.yml, as its name does.
#
# The test data has no patient with a NULL race, race 0 or a detailed race, so
# the tests that need one set it in a transaction that they roll back.
describe ConceptQL::Operators::Race do
  def patients(*races)
    CDB.query([ "race", *races ]).query.select_map(:criterion_id).sort
  end

  # The patients table, qualified with its schema. On DuckDB the unqualified
  # name is a view, which cannot be updated.
  def patients_table
    schema = ENV.fetch("SEQUELIZER_SEARCH_PATH").split(",").map { |s| s.strip.to_sym }
                .find { |s| DB.table_exists?(Sequel[s][:patients]) }
    _(schema).wont_be_nil "no schema on the search path has patients"
    Sequel[schema][:patients]
  end

  def with_updated_patients
    skip "Spark cannot update the test data" if DB.database_type.to_sym == :spark

    DB.transaction(rollback: :always) { yield DB[patients_table] }
  end

  describe "with Unknown" do
    it "selects the patients with no race or race concept 0" do
      white = patients("White")
      _(white.size).must_be :>=, 2
      _(DB[:patients].where(Sequel.|({ race_concept_id: nil }, { race_concept_id: 0 })).count).must_equal 0

      with_updated_patients do |table|
        no_race, race_zero = white.first(2)
        table.where(id: no_race).update(race_concept_id: nil)
        table.where(id: race_zero).update(race_concept_id: 0)

        _(patients("Unknown")).must_equal [ no_race, race_zero ].sort
        _(patients("White", "Unknown")).must_equal white
      end
    end
  end

  describe "with a race concept ID" do
    black = 8516
    detailed_black = 38_003_598

    it "selects the more detailed races that race.yml lists under it" do
      _(YAML.load_file(ConceptQL.race_file).fetch(black)).must_include detailed_black

      with_updated_patients do |table|
        patient = patients("White").first
        table.where(id: patient).update(race_concept_id: detailed_black)

        _(patients(black.to_s)).must_include patient
        _(patients(black.to_s)).must_equal patients("Black or African American")
      end
    end

    # The fixture's is-a relationships (OHDSI vocabularies) can also link the
    # detailed races, so this checks race.yml alone, on a database with none.
    it "takes the detailed races from race.yml" do
      cdb = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
      sql = cdb.query([ "race", black.to_s ]).sql

      _(sql).must_match(/"race_concept_id" IN \([^)]*\b#{detailed_black}\b/)
    end
  end
end
