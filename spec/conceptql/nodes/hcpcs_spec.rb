require 'spec_helper'
require 'conceptql/operators/hcpcs'

describe ConceptQL::Operators::Hcpcs do
  it_behaves_like(:standard_vocabulary_operator)

  subject do
    described_class.new
  end

  describe '#table' do
    it 'should be procedure_occurrence' do
      expect(subject.table).to eq(:procedure_occurrence)
    end
  end

  describe '#concept_column' do
    it 'should be procedure_concept_id' do
      expect(subject.concept_column).to eq(:procedure_concept_id)
    end
  end

  describe '#vocabulary_id' do
    it 'should be 5' do
      expect(subject.vocabulary_id).to eq(5)
    end
  end
end

