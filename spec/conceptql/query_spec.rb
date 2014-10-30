require 'spec_helper'
require 'conceptql'

describe ConceptQL::Query do
  describe '#query' do
    it 'passes request on to tree' do
      yaml = Psych.dump({ icd9: '799.22' })
      mock_tree = Minitest::Mock.new
      mock_node = Minitest::Mock.new
      mock_query = Minitest::Mock.new
      mock_db = Minitest::Mock.new

      mock_db.expect :extend_datasets, mock_db, [Module]

      query = ConceptQL::Query.new(mock_db, yaml, mock_tree)
      mock_tree.expect :root, mock_node, [query]
      mock_node.expect :map, [mock_query]
      mock_query.expect :prep_proc=, nil, [Proc]
      query.query

      mock_node.verify
      mock_tree.verify
    end
  end
end
