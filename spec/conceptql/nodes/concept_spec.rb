require 'spec_helper'
require 'conceptql/nodes/concept'

describe ConceptQL::Nodes::Concept do
  it 'behaves itself' do
    ConceptQL::Nodes::Concept.new.must_behave_like(:evaluator)
  end

  class ConceptDouble < ConceptQL::Nodes::Concept
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
    it 'evaluates child' do
      cd = ConceptDouble.new(1)
      db = Sequel.mock
      cd.cql_query.expect :query, cd.cql_query, []
      cd.cql_query.expect :from_self, [], []
      cd.query(db)
      cd.cql_query.verify
    end
  end
end



