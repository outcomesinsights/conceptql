require 'spec_helper'
require 'conceptql/nodes/loinc'

describe ConceptQL::Nodes::Loinc do
  it 'behaves itself' do
    ConceptQL::Nodes::Loinc.new.must_behave_like(:standard_vocabulary_node)
  end

  subject do
    ConceptQL::Nodes::Loinc.new
  end

  describe '#table' do
    it 'should be observation' do
      subject.table.must_equal :observation
    end
  end

  describe '#concept_column' do
    it 'should be procedure_concept_id' do
      subject.concept_column.must_equal :observation_concept_id
    end
  end

  describe '#vocabulary_id' do
    it 'should be 6' do
      subject.vocabulary_id.must_equal 6
    end
  end
end

