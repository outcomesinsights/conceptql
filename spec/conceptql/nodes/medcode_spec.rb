require 'spec_helper'
require 'conceptql/nodes/medcode'

describe ConceptQL::Nodes::Medcode do
  it 'behaves itself' do
    ConceptQL::Nodes::Medcode.new.must_behave_like(:source_vocabulary_node)
  end

  subject do
    ConceptQL::Nodes::Medcode.new
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
    it 'should be 203 (a J&J provided mapping as part of CPRD)' do
      subject.vocabulary_id.must_equal 203
    end
  end
end
