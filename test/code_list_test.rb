require_relative 'helper'
require_relative 'db'
require_relative '../lib/conceptql/query'
require_relative '../lib/conceptql/database'

describe ConceptQL::Operators do 

  it "should do the listings" do 
    dbConnection = ConceptQL::Database.new(DB)
    query = dbConnection.query(["union",["cpt","99214"],["icd9", "250.00", "250.02"]])
    puts JSON.generate(query.code_list(DB))
      
  end
end