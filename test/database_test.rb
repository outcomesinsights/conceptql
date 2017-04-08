require_relative 'helper'
require_relative 'db'
require_relative '../lib/conceptql/database'

describe ConceptQL::Operators do
  it "should properly quote options for SET" do
    db = ConceptQL::Database.new(DB, db_type: :impala)
    db_type = "IMPALA"
    key = "#{db_type}_DB_OPT_REQUEST_POOL"
    ENV[key] = "svc-jigsaw-tst"
    db.db_opts["request_pool"].must_equal(%Q|"svc-jigsaw-tst"|)
  end

  it "should not quote other options for SET" do
    db = ConceptQL::Database.new(DB, db_type: :impala)
    db_type = "IMPALA"
    key = "#{db_type}_DB_OPT_REQUEST_POOL"
    ENV[key] = "svcjigsawtst"
    db.db_opts["request_pool"].must_equal(%Q|svcjigsawtst|)
  end
end
