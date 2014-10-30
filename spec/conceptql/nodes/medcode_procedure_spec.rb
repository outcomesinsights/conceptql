require 'spec_helper'
require 'conceptql/nodes/medcode_procedure'

describe ConceptQL::Nodes::MedcodeProcedure do
  it 'behaves itself' do
    ConceptQL::Nodes::MedcodeProcedure.new.must_behave_like(:source_vocabulary_node)
  end

  subject do
    ConceptQL::Nodes::MedcodeProcedure.new
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

  describe '#source_column' do
    it 'should be procedure_source_valuej' do
      subject.source_column.must_equal :procedure_source_value
    end
  end

  describe '#vocabulary_id' do
    it 'should be 204 (a J&J provided mapping as part of CPRD)' do
      subject.vocabulary_id.must_equal 204
    end
  end
end
