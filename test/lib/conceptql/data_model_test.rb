# frozen_string_literal: true

require_relative "../../helper"

# ConceptQL supports only the GDM data models. The OMOP CDM model omopv4_plus
# was removed in 0.5.0 (bead conceptql-z09). No live database is needed.
describe ConceptQL::DataModel do
  it "supports gdm and gdm_wide" do
    _(ConceptQL::DataModel::SUPPORTED).must_equal %i[gdm gdm_wide]
  end

  it "says that omopv4_plus was removed when a Database asks for it" do
    error = _ { ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :omopv4_plus) }
            .must_raise ConceptQL::DataModel::UnsupportedError

    _(error.message).must_equal "The omopv4_plus data model was removed in ConceptQL 0.5.0. Use one of: gdm, gdm_wide."
  end

  it "names the supported models for an unknown data model" do
    error = _ { ConceptQL::DataModel.get(:omop54) }.must_raise ConceptQL::DataModel::UnsupportedError

    _(error.message).must_equal "ConceptQL has no data model :omop54. Use one of: gdm, gdm_wide."
  end

  it "refuses an unsupported model passed to Database#operators" do
    cdb = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)

    _ { cdb.operators(:omopv4_plus) }.must_raise ConceptQL::DataModel::UnsupportedError
  end

  it "is an ArgumentError" do
    _(ConceptQL::DataModel::UnsupportedError.ancestors).must_include ArgumentError
  end
end
