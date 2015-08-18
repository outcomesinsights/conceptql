require 'spec_helper'
require 'conceptql/operators/loinc'

describe ConceptQL::Operators::Loinc do
  it_behaves_like(:standard_vocabulary_operator)

  subject do
    described_class.new
  end

  describe '#table' do
    it 'should be observation' do
      expect(subject.table).to eq(:observation)
    end
  end

  describe '#concept_column' do
    it 'should be procedure_concept_id' do
      expect(subject.concept_column).to eq(:observation_concept_id)
    end
  end

  describe '#vocabulary_id' do
    it 'should be 6' do
      expect(subject.vocabulary_id).to eq(6)
    end
  end
end

