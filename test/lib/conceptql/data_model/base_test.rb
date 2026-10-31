# frozen_string_literal: true

require_relative "../../../helper"

# Bead conceptql-5o04: table_columns printed its result and its arguments to
# stdout with `p`, debug output left from the Vocabulary Overhaul (cb39963c).
# It reads only the YAML schema, so no live database is needed.
describe ConceptQL::DataModel::Base do
  let(:cdb) { ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm) }
  let(:dm) { ConceptQL::DataModel::Gdm.new(nil, ConceptQL::Nodifier.new(cdb)) }

  describe "#table_columns" do
    it "returns the schema columns of each table in order" do
      _(dm.table_columns(:patients, :deaths)).must_equal(
        %i[id gender_concept_id birth_date race_concept_id ethnicity_concept_id address_id
           practitioner_id patient_id_source_value
           id patient_id date cause_concept_id cause_type_concept_id practitioner_id]
      )
    end

    it "accepts a qualified table name" do
      _(dm.table_columns(Sequel[:slim][:deaths])).must_equal(
        %i[id patient_id date cause_concept_id cause_type_concept_id practitioner_id]
      )
    end

    it "writes nothing to stdout or stderr" do
      _ { dm.table_columns(:patients, :deaths) }.must_output("", "")
    end
  end
end
