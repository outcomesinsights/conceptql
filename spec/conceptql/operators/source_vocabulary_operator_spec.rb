require 'spec_helper'
require 'conceptql/operators/source_vocabulary_operator'

describe ConceptQL::Operators::SourceVocabularyOperator do
  it_behaves_like(:evaluator)

  class SourceVocabularyDouble < ConceptQL::Operators::SourceVocabularyOperator
    def table
      :table
    end

    def source_column
      :source_column
    end

    def concept_column
      :concept_column
    end

    def vocabulary_id
      1
    end
  end

  describe '#query' do
    it 'works for single values' do
      expect(SourceVocabularyDouble.new('value').query(Sequel.mock).sql).to eq("SELECT * FROM table AS tab INNER JOIN vocabulary.source_to_concept_map AS scm ON ((scm.target_concept_id = tab.concept_column) AND (scm.source_code = tab.source_column)) WHERE ((scm.source_code IN ('value')) AND (scm.source_vocabulary_id = 1))")
    end

    it 'works for multiple values' do
      expect(SourceVocabularyDouble.new('value', 'value2').query(Sequel.mock).sql).to eq("SELECT * FROM table AS tab INNER JOIN vocabulary.source_to_concept_map AS scm ON ((scm.target_concept_id = tab.concept_column) AND (scm.source_code = tab.source_column)) WHERE ((scm.source_code IN ('value', 'value2')) AND (scm.source_vocabulary_id = 1))")
    end

    it 'supports union optimization' do
      sql = lambda do |str|
        "SELECT * FROM (SELECT person_id, condition_occurrence_id AS criterion_id, CAST('condition_occurrence' AS varchar(255)) AS criterion_type, CAST(condition_start_date AS date) AS start_date, coalesce(CAST(condition_end_date AS date), condition_start_date) AS end_date, CAST(NULL AS double precision) AS value_as_number, CAST(NULL AS varchar(255)) AS value_as_string, CAST(NULL AS integer) AS value_as_concept_id, CAST(NULL AS varchar(255)) AS units_source_value, CAST(condition_source_value AS varchar(255)) AS source_value FROM condition_occurrence AS tab INNER JOIN vocabulary.source_to_concept_map AS scm ON ((scm.target_concept_id = tab.condition_concept_id) AND (scm.source_code = tab.condition_source_value)) WHERE (#{str})) AS t1"
      end

      expect(ConceptQL::Operators::Union.new(ConceptQL::Operators::Icd9.new('value'), ConceptQL::Operators::Icd9.new('value2')).optimized.query(Sequel.mock).sql).to eq(sql["(scm.source_code IN ('value', 'value2')) AND (scm.source_vocabulary_id = 2)"])

      expect(ConceptQL::Operators::Union.new(ConceptQL::Operators::Icd9.new('value'), ConceptQL::Operators::Icd10.new('value2')).optimized.query(Sequel.mock).sql).to eq(sql["((scm.source_code IN ('value')) AND (scm.source_vocabulary_id = 2)) OR ((scm.source_code IN ('value2')) AND (scm.source_vocabulary_id = 34))"])

      expect(ConceptQL::Operators::Union.new(ConceptQL::Operators::Icd9.new('value'), ConceptQL::Operators::Icd10.new('value3'), ConceptQL::Operators::Icd9.new('value2')).optimized.query(Sequel.mock).sql).to eq(sql["((scm.source_code IN ('value3')) AND (scm.source_vocabulary_id = 34)) OR ((scm.source_code IN ('value', 'value2')) AND (scm.source_vocabulary_id = 2))"])

      expect(ConceptQL::Operators::Union.new(ConceptQL::Operators::Icd9.new('value4'), ConceptQL::Operators::Union.new(ConceptQL::Operators::Icd9.new('value'), ConceptQL::Operators::Icd10.new('value3'), ConceptQL::Operators::Icd9.new('value2'))).optimized.query(Sequel.mock).sql).to eq(sql["((scm.source_code IN ('value3')) AND (scm.source_vocabulary_id = 34)) OR ((scm.source_code IN ('value4', 'value', 'value2')) AND (scm.source_vocabulary_id = 2))"])

      expect(ConceptQL::Operators::Union.new(ConceptQL::Operators::Union.new(ConceptQL::Operators::Icd9.new('value'), ConceptQL::Operators::Icd10.new('value3'), ConceptQL::Operators::Icd9.new('value2')), ConceptQL::Operators::Icd9.new('value4')).optimized.query(Sequel.mock).sql).to eq(sql["((scm.source_code IN ('value3')) AND (scm.source_vocabulary_id = 34)) OR ((scm.source_code IN ('value', 'value2', 'value4')) AND (scm.source_vocabulary_id = 2))"])

      expect(ConceptQL::Operators::Union.new(ConceptQL::Operators::Icd9.new('value4'), ConceptQL::Operators::Union.new(ConceptQL::Operators::Icd9.new('value'), ConceptQL::Operators::Icd10.new('value3')), ConceptQL::Operators::Icd9.new('value2')).optimized.query(Sequel.mock).sql).to eq(sql["((scm.source_code IN ('value3')) AND (scm.source_vocabulary_id = 34)) OR ((scm.source_code IN ('value4', 'value', 'value2')) AND (scm.source_vocabulary_id = 2))"])

      expect(ConceptQL::Operators::Union.new(ConceptQL::Operators::Icd9.new('value4'), ConceptQL::Operators::Union.new(ConceptQL::Operators::Icd9.new('value'), ConceptQL::Operators::Union.new(ConceptQL::Operators::Icd10.new('value3'), ConceptQL::Operators::Icd9.new('value2')))).optimized.query(Sequel.mock).sql).to eq(sql["((scm.source_code IN ('value3')) AND (scm.source_vocabulary_id = 34)) OR ((scm.source_code IN ('value4', 'value', 'value2')) AND (scm.source_vocabulary_id = 2))"])
    end
  end
end

