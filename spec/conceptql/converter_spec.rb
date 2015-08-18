require 'spec_helper'
require 'conceptql/converter'

describe ConceptQL::Converter do
  describe '#convert' do
    it 'convert {icd9: 412} to [:icd9, "412"]' do
      statement = { icd9: '412' }
      expect(ConceptQL::Converter.new.convert(statement)).to eq([:icd9, '412'])
    end

    it 'convert {icd9: ["412", "200"]} to [:icd9, "412"]' do
      statement = { icd9: %w(412 200) }
      expect(ConceptQL::Converter.new.convert(statement)).to eq([:icd9, '412', '200'])
    end

    it 'convert { first: {icd9: ["412", "200"]}} to [:first, [:icd9, "412"] ]' do
      statement = {
        first: {
          icd9: %w(412 200)
        }
      }
      expect(ConceptQL::Converter.new.convert(statement)).to eq([:first, [:icd9, '412', '200'] ])
    end

    it 'convert operators in options to list-syntax' do
      statement = {
        after: {
          left: {
            icd9: '412'
          },
          right: {
            icd9: '200'

          }
        }
      }
      expect(ConceptQL::Converter.new.convert(statement)).to eq([:after, { left: [:icd9, '412'], right: [:icd9, '200'] }])
    end

    it 'converts operators with an array of upstreams' do
      statement = {
        intersect: [
          { icd9: '412' },
          { condition_type: :inpatient_header }
        ]
      }
      expect(ConceptQL::Converter.new.convert(statement)).to eq([:intersect, [ :icd9, '412' ], [ :condition_type, :inpatient_header ] ])
    end
  end
end

