require_relative "../../../helper"

describe "ConceptQL::Operators::Icd9" do
  it "should use unique names for 'args table' under Impala" do
    db = ConceptQL::Database.new(Sequel.mock(host: :impala), data_model: :omopv4_plus, force_temp_tables: true, scratch_database: "jigsaw_temp")
    values = (1..11_000).to_a
    stmt = [ :union,
      [:icd9, *values],
      [:icd9, *values]
    ]

    sql = db.query(stmt).sql(:create_tables)
    match_data = sql.scan(/FROM `(args_[^`]+)/).flatten
    match_data[0].must_match(/args_\d+/)
    match_data[1].must_match(/args_\d+/)
    match_data[0].wont_equal(match_data[1])
    match_data.length.must_equal 2
  end
end



