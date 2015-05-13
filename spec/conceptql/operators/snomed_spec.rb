require 'spec_helper'
require 'conceptql/operators/snomed'

describe ConceptQL::Operators::Snomed do
  it_behaves_like(:standard_vocabulary_operator)

  subject do
    described_class.new
  end

  describe '#table' do
    it 'should be condition_occurrence' do
      expect(subject.table).to eq(:condition_occurrence)
    end
  end

  describe '#concept_column' do
    it 'should be condition_concept_id' do
      expect(subject.concept_column).to eq(:condition_concept_id)
    end
  end

  describe '#vocabulary_id' do
    it 'should be 1' do
      expect(subject.vocabulary_id).to eq(1)
    end
  end
end

