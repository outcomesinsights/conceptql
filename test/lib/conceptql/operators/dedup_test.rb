# frozen_string_literal: true

require_relative "../../../helper"

# Dedup no longer has only_columns, except_columns or query_columns. Like any
# option an operator does not read, each one is now ignored: the SQL is the SQL
# of a plain dedup, validation reports nothing, and the annotation keeps the
# option as the statement gave it.
describe ConceptQL::Operators::Dedup do
  def cdb
    ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
  end

  def masked_sql(statement)
    cdb.query(statement).sql.gsub(/_\d+_\d+_\h{32}/, "_CTE")
  end

  plain = [ "dedup", [ "icd9", "412" ] ]
  removed_options = {
    "only_columns" => %w[person_id start_date],
    "except_columns" => %w[criterion_id],
    "query_columns" => %w[person_id criterion_domain start_date]
  }

  it "groups by every column" do
    _(masked_sql(plain)).must_include 'GROUP BY "person_id", "criterion_id", "criterion_table", "criterion_domain"'
  end

  removed_options.each do |name, columns|
    it "ignores #{name} given as strings, as JSON gives it" do
      _(masked_sql(plain + [ { name => columns } ])).must_equal masked_sql(plain)
    end

    it "ignores #{name} given as symbols" do
      _(masked_sql(plain + [ { name.to_sym => columns.map(&:to_sym) } ])).must_equal masked_sql(plain)
    end

    it "reports no error or warning for #{name}, and keeps it in the annotation" do
      query = cdb.query(plain + [ { name => columns } ])
      scope = query.scope_annotate(skip_db: true)

      _(scope[:errors]).must_be_empty
      _(scope[:warnings]).must_be_empty
      _(query.annotate(skip_db: true).last[name.to_sym]).must_equal columns
    end
  end
end
