require 'spec_helper'
require 'conceptql/nodes/cpt'

describe ConceptQL::Nodes::Cpt do
  it 'behaves itself' do
    ConceptQL::Nodes::Cpt.new.must_behave_like(:standard_vocabulary_node)
  end

  subject do
    ConceptQL::Nodes::Cpt.new
  end

  describe '#table' do
    it 'should be procedure_occurrence' do
      subject.table.must_equal :procedure_occurrence
    end
  end

  describe '#concept_column' do
    it 'should be procedure_concept_id' do
      subject.concept_column.must_equal :procedure_concept_id
    end
  end

  describe '#vocabulary_id' do
    it 'should be 4' do
      subject.vocabulary_id.must_equal 4
    end
  end
end

