# frozen_string_literal: true

require_relative '../../../helper'
require 'conceptql'

describe ConceptQL::Operators::InformationPeriods do
  it 'should appear for both GDM' do
    _(ConceptQL::Operators.operators[:gdm]['information_periods']).must_equal ConceptQL::Operators::InformationPeriods
  end

  it 'should appear for both OMOPv4+' do
    _(ConceptQL::Operators.operators[:omopv4_plus]['information_periods']).must_equal ConceptQL::Operators::InformationPeriods
  end

  it 'should produce correct SQL under gdm' do
    cdb = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
    check_sequel(cdb.query(['information_periods']), :information_periods, :gdm)
  end

  it 'should produce correct SQL under omopv4_plus' do
    cdb = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :omopv4_plus)
    check_sequel(cdb.query(['information_periods']), :information_periods, :omopv4_plus)
  end
end
