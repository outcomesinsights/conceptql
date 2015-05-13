require 'spec_helper'
require 'conceptql/operators/concept'

describe ConceptQL::Operators::Concept do
  it_behaves_like(:evaluator)

  class ConceptDouble < ConceptQL::Operators::Concept
    attr_accessor :cql_query

    def arguments
      [1]
    end

    def set_statement(value)
      @statement = { icd9: '412' }
    end

    def set_cql_query(db)
      @cql_query ||= nil
    end

    def cql_query
      set_cql_query(nil)
    end
  end

  describe '#query' do
    it 'evaluates upstream' do
      cd = ConceptDouble.new(1)
      db = Sequel.mock
      cd.cql_query = double("query")
      expect(cd.cql_query).to receive(:query).and_return(cd.cql_query)
      expect(cd.cql_query).to receive(:from_self)
      cd.query(db)
    end
  end
end



