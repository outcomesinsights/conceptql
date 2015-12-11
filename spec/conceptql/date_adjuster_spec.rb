require 'spec_helper'
require 'conceptql/date_adjuster'

describe ConceptQL::DateAdjuster do
  describe '#adjustments' do
    it 'returns nothing for input of ""' do
      expect(ConceptQL::DateAdjuster.new('').adjustments).to eq([])
    end

    it 'returns nothing for input of "0"' do
      expect(ConceptQL::DateAdjuster.new('').adjustments).to eq([])
    end

    it 'returns nothing for input of nil' do
      expect(ConceptQL::DateAdjuster.new(nil).adjustments).to eq([])
    end

    it 'returns single day for input of "1"' do
      expect(ConceptQL::DateAdjuster.new('1').adjustments).to eq([[:days, 1]])
    end

    it 'returns 20 days for input of "20"' do
      expect(ConceptQL::DateAdjuster.new('20').adjustments).to eq([[:days, 20]])
    end

    it 'returns single day for input of "d"' do
      expect(ConceptQL::DateAdjuster.new('d').adjustments).to eq([[:days, 1]])
    end

    it 'returns single month for input of "m"' do
      expect(ConceptQL::DateAdjuster.new('m').adjustments).to eq([[:months, 1]])
    end

    it 'returns single year for input of "y"' do
      expect(ConceptQL::DateAdjuster.new('y').adjustments).to eq([[:years, 1]])
    end

    it 'returns 2 days for input of "2d"' do
      expect(ConceptQL::DateAdjuster.new('2d').adjustments).to eq([[:days, 2]])
    end

    it 'returns 2 months for input of "2m"' do
      expect(ConceptQL::DateAdjuster.new('2m').adjustments).to eq([[:months, 2]])
    end

    it 'returns 2 years for input of "2y"' do
      expect(ConceptQL::DateAdjuster.new('2y').adjustments).to eq([[:years, 2]])
    end

    it 'returns negative single day for input of "-d"' do
      expect(ConceptQL::DateAdjuster.new('-d').adjustments).to eq([[:days, -1]])
    end

    it 'returns negative single day, positive single month for "-dm"' do
      expect(ConceptQL::DateAdjuster.new('-dm').adjustments).to eq([[:days, -1], [:months, 1]])
    end

    it 'returns negative 2 days for "-2d"' do
      expect(ConceptQL::DateAdjuster.new('-2d').adjustments).to eq([[:days, -2]])
    end

    it 'returns positive 2 days for "2d"' do
      expect(ConceptQL::DateAdjuster.new('2d').adjustments).to eq([[:days, 2]])
    end
  end
end


