# frozen_string_literal: true

require_relative '../../../helper'
require 'conceptql'

describe ConceptQL::Operators::MultipleVocabularies do
  it 'should appear for both GDM' do
    _(ConceptQL::Operators.operators[:gdm]['cpt_or_hcpcs']).must_equal ConceptQL::Operators::MultipleVocabularies
  end

  it 'should produce correct SQL under gdm' do
    db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
    sql = _(db.query(%w[cpt_or_hcpcs 99214]).sql)
    sql.must_match(/"clinical_code_vocabulary_id" = 'HCPCS'/)
    sql.must_match(/"clinical_code_vocabulary_id" = 'CPT4'/)
  end

  it 'should produce correct SQL under omopv4_plus' do
    db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :omopv4_plus)
    sql = _(db.query(%w[cpt_or_hcpcs 99214]).sql)
    sql.must_match(/"procedure_source_vocabulary_id" = 4/)
    sql.must_match(/"procedure_source_vocabulary_id" = 5/)
  end

  it 'should read operators from a custom file' do
    assert_empty(ConceptQL::Operators::MultipleVocabularies.get_multiple_vocabularies.select do |_key, row|
      row.first[:operator] == 'test'
    end)
    Tempfile.create('blah.csv') do |f|
      CSV(f) do |csv|
        csv << %w[operator vocabulary_id domain]
        csv << %w[test test_id test_domain]
      end
      f.rewind
      ConceptQL.stub(:custom_multiple_vocabularies_file_path, Pathname.new(f.path)) do
        refute_empty(ConceptQL::Operators::MultipleVocabularies.get_multiple_vocabularies.select do |_key, row|
          row.first[:operator] == 'test'
        end)
      end
    end
    assert_empty(ConceptQL::Operators::MultipleVocabularies.get_multiple_vocabularies.select do |_key, row|
      row.first[:operator] == 'test'
    end)
  end
end
