require 'spec_helper'
require 'conceptql/operators/rxnorm'

describe ConceptQL::Operators::Rxnorm do
  it 'behaves itself' do
    ConceptQL::Operators::Rxnorm.new.must_behave_like(:standard_vocabulary_node)
  end

  subject do
    ConceptQL::Operators::Rxnorm.new
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

  describe '#vocabulary_id' do
    it 'should be 8' do
      subject.vocabulary_id.must_equal 8
    end
  end
end

