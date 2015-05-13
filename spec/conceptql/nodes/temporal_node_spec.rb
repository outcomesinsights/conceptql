require 'spec_helper'
require 'conceptql/operators/temporal_operator'
require_double('stream_for_temporal')

describe ConceptQL::Operators::TemporalOperator do
  it_behaves_like(:evaluator)

  class TemporalDouble < ConceptQL::Operators::TemporalOperator
    def where_clause
      Proc.new do
        l__end_date < r__start_date
      end
    end
  end

  describe TemporalDouble do
    it_behaves_like(:temporal_operator)
  end

  describe StreamForTemporalDouble do
    it_behaves_like(:evaluator)
  end

  describe '#inclusive?' do
    it 'defaults to false' do
      expect(TemporalDouble.new.inclusive?).to be_falsy
    end

    it 'can be set to true' do
      expect(TemporalDouble.new(inclusive: true).inclusive?).to be_truthy
    end
  end

  describe '#query' do
    it 'uses logic from where_clause' do
      sql = TemporalDouble.new(left: StreamForTemporalDouble.new, right: StreamForTemporalDouble.new).query(Sequel.mock).sql
      expect(sql).to match('l.end_date < r.start_date')
    end

    it 'pulls from the right tables' do
      sql = TemporalDouble.new(left: StreamForTemporalDouble.new, right: StreamForTemporalDouble.new).query(Sequel.mock).sql
      expect(sql).to match('FROM table')
    end

    it 'is ok with symbols' do
      sql = TemporalDouble.new(left: StreamForTemporalDouble.new, right: StreamForTemporalDouble.new).query(Sequel.mock).sql
      expect(sql).to match('FROM table')
    end
  end
end

