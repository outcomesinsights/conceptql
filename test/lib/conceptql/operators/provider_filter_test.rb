# frozen_string_literal: true

require_relative '../../../helper'
require 'conceptql'

describe ConceptQL::Operators::ProviderFilter do
  describe 'in gdm' do
    let(:dm) { :gdm }

    it 'should not apply a WHERE clause when given * for both specialties and roles' do
      db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: dm)
      _(db.query(['provider_filter', %w[icd9 412],
                  { 'specialties' => '38004458, *', 'roles' => '*' }]).sql).wont_match(/"specialty_concept_id" (IN|=)/i)
      _(db.query(['provider_filter', %w[icd9 412],
                  { 'specialties' => '38004458, *', 'roles' => '*' }]).sql).wont_match(/"role_type_concept_id" (IN|=)/i)
    end

    it 'should find specialty_concept_id and role_type_concept_id in condition_occurrence table' do
      db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: dm)
      _(db.query(['provider_filter', %w[icd9 412],
                  { 'specialties' => '38004458', 'roles' => '38004459' }]).sql).must_match(/specialty_concept_id/)
      _(db.query(['provider_filter', %w[icd9 412],
                  { 'specialties' => '38004458', 'roles' => '38004459' }]).sql).must_match(/role_type_concept_id/)
    end

    it 'should find specialty_concept_id and role_type_concept_id in procedure_occurrence table' do
      db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: dm)
      _(db.query(['provider_filter', %w[cpt 99214],
                  { 'specialties' => '38004458', 'roles' => '38004459' }]).sql).must_match(/specialty_concept_id/)
      _(db.query(['provider_filter', %w[cpt 99214],
                  { 'specialties' => '38004458', 'roles' => '38004459' }]).sql).must_match(/role_type_concept_id/)
    end

    it 'should add no columns in person table' do
      db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: dm)
      _(db.query(['provider_filter', ['person'],
                  { 'specialties' => '38004458', 'roles' => '38004459' }]).sql).wont_match(/"provider_id"\s*AS/i)
    end

    it 'should find specialty_concept_id and role_type_concept_id in procedure_occurrence table for NDC codes' do
      db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: dm)
      _(db.query(['provider_filter', %w[ndc 0123456789],
                  { 'specialties' => '38004458', 'roles' => '38004459' }]).sql).must_match(/specialty_concept_id/)
      _(db.query(['provider_filter', %w[ndc 0123456789],
                  { 'specialties' => '38004458', 'roles' => '38004459' }]).sql).must_match(/role_type_concept_id/)
    end

    it 'should apply role filter when only roles are specified' do
      db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: dm)
      _(db.query(['provider_filter', %w[icd9 412],
                  { 'specialties' => '*', 'roles' => '38004459' }]).sql).must_match(/role_type_concept_id/)
      _(db.query(['provider_filter', %w[icd9 412],
                  { 'specialties' => '*', 'roles' => '38004459' }]).sql).wont_match(/"specialty_concept_id" (IN|=)/i)
    end

    it 'should apply specialty filter when only specialties are specified' do
      db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: dm)
      _(db.query(['provider_filter', %w[icd9 412],
                  { 'specialties' => '38004458', 'roles' => '*' }]).sql).must_match(/specialty_concept_id/)
      _(db.query(['provider_filter', %w[icd9 412],
                  { 'specialties' => '38004458', 'roles' => '*' }]).sql).wont_match(/"role_type_concept_id" (IN|=)/i)
    end
  end
end
