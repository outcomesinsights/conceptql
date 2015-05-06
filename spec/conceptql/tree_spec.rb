require 'spec_helper'
require 'conceptql/tree'

describe ConceptQL::Tree do
  describe '#root' do
    before do
      @mock_query_obj = Minitest::Mock.new
      @mock_nodifier = Minitest::Mock.new
      @tree = ConceptQL::Tree.new(nodifier: @mock_nodifier)
    end

    after do
      @mock_query_obj.verify
      @mock_nodifier.verify
    end

    it 'should walk single node criteria tree and convert to node' do
      @mock_nodifier.expect :create, :success_indicator, [:icd9, '799.22', @tree]
      @mock_query_obj.expect :statement, { icd9: '799.22' }

      @tree.root(@mock_query_obj).must_equal :success_indicator
    end

    it 'should extend all nodes created with behavior passed in' do
      mock_icd9_obj = Minitest::Mock.new
      mock_icd9_obj.expect :extend, nil, [:mock_behavior]

      tree = ConceptQL::Tree.new(nodifier: @mock_nodifier, behavior: :mock_behavior)
      @mock_nodifier.expect :create, mock_icd9_obj, [:icd9, '799.22', tree]
      @mock_query_obj.expect :statement, { icd9: '799.22' }

      tree.root(@mock_query_obj)
    end

    it 'should walk multi-criteria node' do
      @mock_nodifier.expect :create, :mock_icd9, [:icd9, '799.22', @tree]
      @mock_nodifier.expect :create, :success_indicator, [:nth, { occurrence: 1, expression: :mock_icd9 }, @tree]

      @mock_query_obj.expect :statement, { nth: { occurrence: 1, expression: { icd9: '799.22' } } }

      @tree.root(@mock_query_obj).must_equal :success_indicator
    end

    it 'should walk multi-node criteria tree and convert to nodes' do
      @mock_nodifier.expect :create, :mock_icd9, [:icd9, '799.22', @tree]
      @mock_nodifier.expect :create, :success_indicator, [:any, :mock_icd9, @tree]

      @mock_query_obj.expect :statement, { any: [{ icd9: '799.22' }] }

      @tree.root(@mock_query_obj).must_equal :success_indicator
    end
  end
end

