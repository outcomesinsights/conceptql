# frozen_string_literal: true

require_relative "../../../helper"

# t_shank passes join_columns as symbols. A JSON statement gives them as
# strings, and both must give the same SQL.
describe ConceptQL::Operators::TrimDate do
  def masked_sql(statement)
    ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
                       .query(statement).sql
                       .gsub(/_\d+_\d+_\h{32}/, "_CTE")
  end

  def stringified(statement)
    JSON.parse(JSON.generate(statement))
  end

  uuid_icd9 = [ :icd9, "412", { uuid: true } ]
  shifted = [ :time_window, uuid_icd9, { start: "-30d", end: "-30d" } ]

  %i[trim_date_end trim_date_start].each do |operator|
    [ false, true ].each do |compare_all|
      it "gives the same SQL for string and symbol join_columns (#{operator}, compare_all: #{compare_all})" do
        statement = [ operator, { left: uuid_icd9, right: shifted, join_columns: [ :uuid ], compare_all: compare_all } ]

        symbol_sql = masked_sql(statement)
        _(symbol_sql).must_include '"l"."uuid" = "r"."uuid"'
        _(symbol_sql).wont_include "'uuid'"
        _(masked_sql(stringified(statement))).must_equal symbol_sql
      end
    end
  end
end
