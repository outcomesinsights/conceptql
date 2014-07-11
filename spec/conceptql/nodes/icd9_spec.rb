require 'spec_helper'
require 'conceptql/nodes/icd9'

describe ConceptQL::Nodes::Icd9 do
  it 'behaves itself' do
    ConceptQL::Nodes::Icd9.new.must_behave_like(:source_vocabulary_node)
  end

  subject do
    ConceptQL::Nodes::Icd9.new
  end

  describe '#table' do
    it 'should be condition_occurrence' do
      subject.table.must_equal :condition_occurrence
    end
  end

  describe '#concept_column' do
    it 'should be condition_concept_id' do
      subject.concept_column.must_equal :condition_concept_id
    end
  end

  describe '#source_column' do
    it 'should be condition_source_valuej' do
      subject.source_column.must_equal :condition_source_value
    end
  end

  describe '#vocabulary_id' do
    it 'should be 2' do
      subject.vocabulary_id.must_equal 2
    end
  end
end
