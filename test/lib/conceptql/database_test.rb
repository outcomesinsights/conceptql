# frozen_string_literal: true

require_relative '../../db_helper'

describe ConceptQL::Database do
  describe '#type_for' do
    let(:db) { ConceptQL::Database.new(Sequel.mock(host: :postgres)) }

    it 'should return correct type for default columns' do
      # Test some default columns
      _(db.type_for(:person_id)).must_equal :Bigint
      _(db.type_for(:criterion_table)).must_equal :String
      _(db.type_for(:start_date)).must_equal :Date
      _(db.type_for(:source_value)).must_equal :String
    end

    it 'should return correct type for additional columns' do
      # Test some additional columns
      _(db.type_for(:value_as_number)).must_equal :Float
      _(db.type_for(:drug_days_supply)).must_equal :Bigint
      _(db.type_for(:drug_name)).must_equal :String
      _(db.type_for(:admission_date)).must_equal :Date
    end

    it 'should raise KeyError for unknown columns' do
      _(proc { db.type_for(:nonexistent_column) }).must_raise KeyError
    end
  end
end
