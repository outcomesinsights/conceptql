require 'spec_helper'
require 'conceptql/nodes/snomed'

describe ConceptQL::Operators::Snomed do
  it 'behaves itself' do
    ConceptQL::Operators::Snomed.new.must_behave_like(:standard_vocabulary_node)
  end

  subject do
    ConceptQL::Operators::Snomed.new
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

  describe '#vocabulary_id' do
    it 'should be 1' do
      subject.vocabulary_id.must_equal 1
    end
  end
end

