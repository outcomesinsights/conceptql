require 'spec_helper'
require 'conceptql'

describe ConceptQL::Query do
  describe '#query' do
    it 'passes request on to tree' do
      yaml = Psych.dump({ icd9: '799.22' })
      mock_tree = double("tree")
      mock_operator = double("operator")
      mock_query = double("query")
      mock_db = double("db")

      expect(mock_db).to receive(:extend_datasets).with(Module).and_return(mock_db)

      query = ConceptQL::Query.new(mock_db, yaml, mock_tree)
      expect(mock_tree).to receive(:root).with(query).and_return(mock_operator)
      expect(mock_operator).to receive(:evaluate).with(mock_db).and_return(mock_query)
      expect(mock_query).to receive(:tap).and_return(mock_query)
      query.query
    end
  end
end
