require 'spec_helper'
require 'conceptql/nodes/temporal_node'
require_double('stream_for_temporal')

describe ConceptQL::Nodes::TemporalNode do
  it 'behaves itself' do
    ConceptQL::Nodes::TemporalNode.new.must_behave_like(:evaluator)
  end

  class TemporalDouble < ConceptQL::Nodes::TemporalNode
    def where_clause
      Proc.new do
        l__end_date < r__start_date
      end
    end
  end

  describe TemporalDouble do
    it 'behaves itself' do
      TemporalDouble.new.must_behave_like(:temporal_node)
    end
  end

  describe StreamForTemporalDouble do
    it 'behaves itself' do
      StreamForTemporalDouble.new.must_behave_like(:evaluator)
    end
  end

  describe '#inclusive?' do
    it 'defaults to false' do
      refute(TemporalDouble.new.inclusive?)
    end

    it 'can be set to true' do
      assert(TemporalDouble.new(inclusive: true).inclusive?)
    end
  end

  describe '#query' do
    it 'uses logic from where_clause' do
      sql = TemporalDouble.new(left: StreamForTemporalDouble.new, right: StreamForTemporalDouble.new).query(Sequel.mock).sql
      sql.must_match('l.end_date < r.start_date')
    end

    it 'pulls from the right tables' do
      sql = TemporalDouble.new(left: StreamForTemporalDouble.new, right: StreamForTemporalDouble.new).query(Sequel.mock).sql
      sql.must_match('FROM table')
    end

    it 'is ok with symbols' do
      sql = TemporalDouble.new(left: StreamForTemporalDouble.new, right: StreamForTemporalDouble.new).query(Sequel.mock).sql
      sql.must_match('FROM table')
    end
  end
end

