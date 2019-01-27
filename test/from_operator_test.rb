require_relative 'db_helper'

if scratch = ENV['DOCKER_SCRATCH_DATABASE']
  describe ConceptQL::Operators::From do
    temp_table = Sequel.qualify(scratch, :from_operator_test)

    after do
      DB.drop_table(temp_table)
    end

    it "should select from the table" do
      DB.create_table(temp_table, :as=>CDB.query([:window, [:person], {person_ids: [1]}]).query)
      CDB.query([:from, "#{scratch}__from_operator_test"]).query.all.must_equal DB[temp_table].all
      CDB.query([:window, [:from, "#{scratch}__from_operator_test"], {person_ids: [1]}]).query.count.must_equal 1
      CDB.query([:window, [:from, "#{scratch}__from_operator_test"], {person_ids: [2]}]).query.count.must_equal 0
    end
  end
end
