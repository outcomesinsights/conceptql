# frozen_string_literal: true

require_relative '../../../helper'
require 'conceptql'

describe ConceptQL::Operators::InformationPeriods do
  def assert_information_periods_sql(query, source_table)
    sql = query.sql

    _(sql).must_match(/WITH "information_periods_\d+_1_\w+" AS MATERIALIZED/i)
    _(sql).must_match(/FROM "#{source_table}"/i)
    _(sql).must_match(/FROM \(SELECT \* FROM "information_periods_\d+_1_\w+"\) AS "t1"/i)
  end

  it 'should appear for both GDM' do
    _(ConceptQL::Operators.operators[:gdm]['information_periods']).must_equal ConceptQL::Operators::InformationPeriods
  end

  it 'should appear for both OMOPv4+' do
    _(ConceptQL::Operators.operators[:omopv4_plus]['information_periods']).must_equal ConceptQL::Operators::InformationPeriods
  end

  it 'should produce correct SQL under gdm' do
    cdb = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
    assert_information_periods_sql(cdb.query(['information_periods']), 'information_periods')
  end

  it 'should produce correct SQL under omopv4_plus' do
    cdb = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :omopv4_plus)
    assert_information_periods_sql(cdb.query(['information_periods']), 'observation_period')
  end
end
