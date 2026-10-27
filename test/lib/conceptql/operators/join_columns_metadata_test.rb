# frozen_string_literal: true

require_relative "../../../helper"

# join_columns is declared in the metadata of exactly the operators that read
# it: the temporal operators (through TemporalOperator) and match, which
# declares its own (beads conceptql-zq2 and conceptql-1t8). filter, except and
# person_filter do not read it, so they do not declare it.
# No live database: the mock never answers a query.
describe "join_columns in ConceptQL.metadata" do
  let(:readers) { %w[after any_overlap before contains during equal match trim_date_end trim_date_start] }

  %i[gdm gdm_wide omopv4_plus].each do |dm|
    describe dm.to_s do
      let(:cdb) { ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: dm) }
      let(:operators_metadata) { ConceptQL.metadata(cdb)[:operators] }

      it "is declared on exactly the operators that read it" do
        declaring = operators_metadata.select { |_name, m| m[:options].key?(:join_columns) }.keys

        _(declaring.sort).must_equal readers
      end

      it "is a string option without a default, and not required" do
        readers.each do |name|
          option = operators_metadata.fetch(name)[:options].fetch(:join_columns)

          _(option[:type]).must_equal :string, name
          _(option.keys).wont_include :default, name
          _(option.keys).wont_include :required, name
        end
      end

      it "keeps match's own instructions" do
        match = operators_metadata.fetch("match")[:options][:join_columns][:instructions]
        before = operators_metadata.fetch("before")[:options][:join_columns][:instructions]

        _(match).must_include "Cannot be used with Only Columns or Except Columns"
        _(before).wont_include "Only Columns"
      end
    end
  end
end
