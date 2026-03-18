# frozen_string_literal: true

require_relative '../../../helper'

describe ConceptQL::Operators::Gender do
  def assert_gender_sql(query, where_pattern)
    sql = query.sql

    _(sql).must_match(/WITH "gender_\d+_1_\w+" AS MATERIALIZED/i)
    _(sql).must_match(where_pattern)
    _(sql).must_match(/FROM \(SELECT \* FROM "gender_\d+_1_\w+"\) AS "t1"/i)
  end

  it 'be present in list of operators' do
    _(ConceptQL::Operators.operators[:omopv4_plus]['gender']).must_equal ConceptQL::Operators::Gender
  end

  describe 'under gdm' do
    let(:db) do
      ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
    end

    it 'should work with male' do
      assert_gender_sql(db.query(%w[gender male]), /WHERE \("gender_concept_id" IN \(8507\)\)/i)
    end

    it 'should work with female' do
      assert_gender_sql(db.query(%w[gender female]), /WHERE \("gender_concept_id" IN \(8532\)\)/i)
    end

    it 'should work with unknown' do
      assert_gender_sql(db.query(%w[gender unknown]), /WHERE \(\("gender_concept_id" IS NULL\) OR \("gender_concept_id" NOT IN \(8507, 8532\)\)\)/i)
    end

    it 'should work with all' do
      assert_gender_sql(
        db.query(%w[gender male female unknown]),
        /WHERE \(\("gender_concept_id" IN \(8507\)\) OR \("gender_concept_id" IN \(8532\)\) OR \("gender_concept_id" IS NULL\) OR \("gender_concept_id" NOT IN \(8507, 8532\)\)\)/i
      )
    end
  end
end
