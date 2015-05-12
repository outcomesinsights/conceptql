require 'spec_helper'
require 'conceptql/operators/prodcode'

describe ConceptQL::Operators::Prodcode do
  it 'behaves itself' do
    ConceptQL::Operators::Prodcode.new.must_behave_like(:source_vocabulary_node)
  end

  subject do
    ConceptQL::Operators::Prodcode.new
  end

  describe '#table' do
    it 'should be drug_exposure' do
      subject.table.must_equal :drug_exposure
    end
  end

  describe '#concept_column' do
    it 'should be drug_concept_id' do
      subject.concept_column.must_equal :drug_concept_id
    end
  end

  describe '#source_column' do
    it 'should be drug_source_valuej' do
      subject.source_column.must_equal :drug_source_value
    end
  end

  describe '#vocabulary_id' do
    it 'should be 200 (a J&J provided mapping as part of CPRD)' do
      subject.vocabulary_id.must_equal 200
    end
  end
end

