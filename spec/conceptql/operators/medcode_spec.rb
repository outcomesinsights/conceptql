require 'spec_helper'
require 'conceptql/operators/medcode'

describe ConceptQL::Operators::Medcode do
  it_behaves_like(:source_vocabulary_operator)

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

  describe '#source_column' do
    it 'should be condition_source_valuej' do
      expect(subject.source_column).to eq(:condition_source_value)
    end
  end

  describe '#vocabulary_id' do
    it 'should be 203 (a J&J provided mapping as part of CPRD)' do
      expect(subject.vocabulary_id).to eq(203)
    end
  end
end
