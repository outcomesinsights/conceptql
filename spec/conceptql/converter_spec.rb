require 'spec_helper'
require 'conceptql/converter'

describe ConceptQL::Converter do
  describe '#convert' do
    it 'convert {icd9: 412} to [:icd9, "412"]' do
      statement = { icd9: '412' }
      ConceptQL::Converter.new.convert(statement).must_equal [:icd9, '412']
    end

    it 'convert {icd9: ["412", "200"]} to [:icd9, "412"]' do
      statement = { icd9: %w(412 200) }
      ConceptQL::Converter.new.convert(statement).must_equal [:icd9, '412', '200']
    end

    it 'convert { first: {icd9: ["412", "200"]}} to [:first, [:icd9, "412"] ]' do
      statement = {
        first: {
          icd9: %w(412 200)
        }
      }
      ConceptQL::Converter.new.convert(statement).must_equal [:first, [:icd9, '412', '200'] ]
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
      ConceptQL::Converter.new.convert(statement).must_equal [:after, { left: [:icd9, '412'], right: [:icd9, '200'] }]
    end
  end
end

