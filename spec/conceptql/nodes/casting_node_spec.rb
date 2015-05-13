require 'spec_helper'
require 'conceptql/operators/casting_operator'
require_double('stream_for_casting')

describe ConceptQL::Operators::CastingOperator do
  it_behaves_like(:evaluator)

  class CastingDouble < ConceptQL::Operators::CastingOperator
    def my_type
      :my_type
    end

    def i_point_at
      [ :i_point1, :i_point2 ]
    end

    def these_point_at_me
      [ :at_me1, :at_me2 ]
    end
  end

  describe CastingDouble do
    it_behaves_like(:casting_operator)
  end

  describe '#query' do
    it 'uses person_ids when an uncastable type is encountered' do
      stream = StreamForCastingDouble.new
      stream.types = [:uncastable]
      sql = CastingDouble.new(stream).query(Sequel.mock).sql
      expect(sql).to match('person_id IN')
      expect(sql).to match('GROUP BY person_id')
      expect(sql).to match('FROM table')
    end

    it 'uses person_ids when an uncastable type is included among castable types' do
      stream = StreamForCastingDouble.new
      stream.types = [:i_point1, :uncastable]
      sql = CastingDouble.new(stream).query(Sequel.mock).sql
      expect(sql).to match('person_id IN')
      expect(sql).to match('GROUP BY person_id')
    end

    it 'uses castable types if possible' do
      stream = StreamForCastingDouble.new
      stream.types = [:i_point1]
      sql = CastingDouble.new(stream).query(Sequel.mock).sql
      expect(sql).to match('i_point1_id IN')
      expect(sql).to match("criterion_type = 'i_point1'")
    end

    it 'uses and unions multiple castable types if possible' do
      stream = StreamForCastingDouble.new
      stream.types = [:i_point1, :at_me2]
      sql = CastingDouble.new(stream).query(Sequel.mock).sql
      expect(sql).to match('my_type_id IN')
      expect(sql).to match('i_point1_id IN')
      expect(sql).to match("criterion_type = 'i_point1'")
    end

    it 'returns all rows of a table if passed the argument "true"' do
      sql = CastingDouble.new(true).query(Sequel.mock).sql
      expect(sql).to match("SELECT * FROM my_type AS tab")
    end
  end
end


