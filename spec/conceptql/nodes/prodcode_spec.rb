require 'spec_helper'
require 'conceptql/operators/prodcode'

describe ConceptQL::Operators::Prodcode do
  it_behaves_like(:source_vocabulary_operator)

  subject do
    described_class.new
  end

  describe '#table' do
    it 'should be drug_exposure' do
      expect(subject.table).to eq(:drug_exposure)
    end
  end

  describe '#concept_column' do
    it 'should be drug_concept_id' do
      expect(subject.concept_column).to eq(:drug_concept_id)
    end
  end

  describe '#source_column' do
    it 'should be drug_source_valuej' do
      expect(subject.source_column).to eq(:drug_source_value)
    end
  end

  describe '#vocabulary_id' do
    it 'should be 200 (a J&J provided mapping as part of CPRD)' do
      expect(subject.vocabulary_id).to eq(200)
    end
  end
end

