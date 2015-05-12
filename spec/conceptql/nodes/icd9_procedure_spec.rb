require 'spec_helper'
require 'conceptql/operators/icd9_procedure'

describe ConceptQL::Operators::Icd9Procedure do
  it 'behaves itself' do
    ConceptQL::Operators::Icd9Procedure.new.must_behave_like(:standard_vocabulary_node)
  end

  subject do
    ConceptQL::Operators::Icd9Procedure.new
  end

  describe '#table' do
    it 'should be procedure_occurrence' do
      subject.table.must_equal :procedure_occurrence
    end
  end

  describe '#concept_column' do
    it 'should be procedure_concept_id' do
      subject.concept_column.must_equal :procedure_concept_id
    end
  end

  describe '#vocabulary_id' do
    it 'should be 3' do
      subject.vocabulary_id.must_equal 3
    end
  end
end

