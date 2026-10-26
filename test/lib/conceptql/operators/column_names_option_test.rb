# frozen_string_literal: true

require_relative "../../../helper"

# Operator#column_names_option reads an option that lists columns. The
# diagram editor's text field gives the list as one comma-separated string,
# and a statement gives an array (bead conceptql-zq2).
# No live database: the mock never answers a query.
describe "Operator#column_names_option" do
  let(:cdb) { ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm_wide) }
  let(:icd) { [ "icd9", "412", { uuid: true } ] }

  def names_for(value)
    cdb.query([ "match", { left: icd, right: icd, join_columns: value } ]).operator.send(:column_names_option, :join_columns)
  end

  # Each CTE name ends in a counter and a random hex suffix
  def masked_sql(statement)
    cdb.query(statement).sql.gsub(/_\d+_\h{32}\b/, "_N_HEX")
  end

  it "reads an array of strings" do
    _(names_for(%w[uuid start_date])).must_equal %i[uuid start_date]
  end

  it "reads an array of symbols" do
    _(names_for(%i[uuid start_date])).must_equal %i[uuid start_date]
  end

  it "reads a comma-separated string" do
    _(names_for("uuid,start_date")).must_equal %i[uuid start_date]
  end

  it "strips spaces and drops empty parts" do
    _(names_for(" uuid , start_date, ,")).must_equal %i[uuid start_date]
  end

  it "reads a blank string as unset" do
    _(names_for("")).must_be_nil
    _(names_for("  ")).must_be_nil
    _(names_for(" , ")).must_be_nil
  end

  it "reads a missing option as unset" do
    _(names_for(nil)).must_be_nil
  end

  # BinaryOperatorOperator#join_columns_option reads through the helper, so
  # the temporal operators and trim_date take the string form too. (filter
  # does not read join_columns.)
  %w[after trim_date_start].each do |name|
    it "gives the same SQL for #{name} join_columns as a string and as an array" do
      from_string = masked_sql([ name, { left: icd, right: icd, join_columns: "uuid, start_date" } ])

      _(from_string).must_equal masked_sql([ name, { left: icd, right: icd, join_columns: %w[uuid start_date] } ])
    end
  end
end
