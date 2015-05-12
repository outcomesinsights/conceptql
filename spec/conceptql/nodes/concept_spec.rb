require 'spec_helper'
require 'conceptql/operators/concept'

describe ConceptQL::Operators::Concept do
  it 'behaves itself' do
    ConceptQL::Operators::Concept.new.must_behave_like(:evaluator)
  end

  class ConceptDouble < ConceptQL::Operators::Concept
    def arguments
      [1]
    end

    def set_statement(value)
      @statement = { icd9: '412' }
    end

    def set_cql_query(db)
      @cql_query ||= Minitest::Mock.new
    end

    def cql_query
      set_cql_query(nil)
    end
  end

  describe '#query' do
    it 'evaluates upstream' do
      cd = ConceptDouble.new(1)
      db = Sequel.mock
      cd.cql_query.expect :query, cd.cql_query, []
      cd.cql_query.expect :from_self, [], []
      cd.query(db)
      cd.cql_query.verify
    end
  end
end



