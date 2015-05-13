require 'spec_helper'
require 'conceptql/tree'

describe ConceptQL::Tree do
  describe '#root' do
    before do
      @mock_query_obj = double("mock  query")
      @mock_nodifier = double("mock nodifier")
      @mock_scope = double("mock scope")
      @tree = ConceptQL::Tree.new(nodifier: @mock_nodifier, scope: @mock_scope)
    end

    it 'should walk single operator criteria tree and convert to operator' do
      expect(@mock_nodifier).to receive(:create).with(@mock_scope, :icd9, '799.22').and_return(:success_indicator)
      expect(@mock_query_obj).to receive(:statement).and_return({ icd9: '799.22' })

      expect(@tree.root(@mock_query_obj)).to eq(:success_indicator)
    end

    it 'should extend all operators created with behavior passed in' do
      mock_icd9_obj = double("mock icd9")
      expect(mock_icd9_obj).to receive(:extend).with(:mock_behavior)

      tree = ConceptQL::Tree.new(nodifier: @mock_nodifier, behavior: :mock_behavior, scope: @mock_scope)
      expect(@mock_nodifier).to receive(:create).with(@mock_scope, :icd9, '799.22').and_return(mock_icd9_obj)
      expect(@mock_query_obj).to receive(:statement).and_return({ icd9: '799.22' })

      tree.root(@mock_query_obj)
    end

    it 'should walk multi-criteria operator' do
      expect(@mock_nodifier).to receive(:create).with(@mock_scope, :icd9, '799.22').and_return(:mock_icd9)
      expect(@mock_nodifier).to receive(:create).with(@mock_scope, :nth, { occurrence: 1, expression: :mock_icd9 }).and_return(:success_indicator)

      expect(@mock_query_obj).to receive(:statement).and_return({ nth: { occurrence: 1, expression: { icd9: '799.22' } } })

      expect(@tree.root(@mock_query_obj)).to eq(:success_indicator)
    end

    it 'should walk multi-operator criteria tree and convert to operators' do
      expect(@mock_nodifier).to receive(:create).with(@mock_scope, :icd9, '799.22').and_return(:mock_icd9)
      expect(@mock_nodifier).to receive(:create).with(@mock_scope, :any, :mock_icd9).and_return(:success_indicator)

      expect(@mock_query_obj).to receive(:statement).and_return({ any: [{ icd9: '799.22' }] })

      expect(@tree.root(@mock_query_obj)).to eq(:success_indicator)
    end
  end
end

