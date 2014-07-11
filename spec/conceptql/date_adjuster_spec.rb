require 'spec_helper'
require 'conceptql/date_adjuster'

describe ConceptQL::DateAdjuster do
  describe '#adjustments' do
    it 'returns nothing for input of ""' do
      ConceptQL::DateAdjuster.new('').adjustments.must_equal []
    end

    it 'returns nothing for input of "0"' do
      ConceptQL::DateAdjuster.new('').adjustments.must_equal []
    end

    it 'returns nothing for input of nil' do
      ConceptQL::DateAdjuster.new(nil).adjustments.must_equal []
    end

    it 'returns single day for input of "1"' do
      ConceptQL::DateAdjuster.new('1').adjustments.must_equal ['1 days']
    end

    it 'returns 20 days for input of "20"' do
      ConceptQL::DateAdjuster.new('20').adjustments.must_equal ['20 days']
    end

    it 'returns single day for input of "d"' do
      ConceptQL::DateAdjuster.new('d').adjustments.must_equal ['1 day']
    end

    it 'returns single month for input of "m"' do
      ConceptQL::DateAdjuster.new('m').adjustments.must_equal ['1 month']
    end

    it 'returns single year for input of "y"' do
      ConceptQL::DateAdjuster.new('y').adjustments.must_equal ['1 year']
    end

    it 'returns 2 days for input of "2d"' do
      ConceptQL::DateAdjuster.new('2d').adjustments.must_equal ['2 days']
    end

    it 'returns 2 months for input of "2m"' do
      ConceptQL::DateAdjuster.new('2m').adjustments.must_equal ['2 months']
    end

    it 'returns 2 years for input of "2y"' do
      ConceptQL::DateAdjuster.new('2y').adjustments.must_equal ['2 years']
    end

    it 'returns negative single day for input of "-d"' do
      ConceptQL::DateAdjuster.new('-d').adjustments.must_equal ['-1 day']
    end

    it 'returns negative single day, positive single month for "-dm"' do
      ConceptQL::DateAdjuster.new('-dm').adjustments.must_equal ['-1 day', '1 month']
    end

    it 'returns negative 2 days for "-2d"' do
      ConceptQL::DateAdjuster.new('-2d').adjustments.must_equal ['-2 days']
    end

    it 'returns positive 2 days for "2d"' do
      ConceptQL::DateAdjuster.new('2d').adjustments.must_equal ['2 days']
    end
  end
end


