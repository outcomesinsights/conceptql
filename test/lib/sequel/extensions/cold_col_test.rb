# frozen_string_literal: true

require_relative '../../../helper'
require_relative '../../../../lib/sequel/extensions/cold_col'

describe Sequel::ColdColDatabase do
  let(:db) do
    @db = Sequel.mock.extension(:cold_col)
    @db.instance_variable_set(:@schemas, {
                                Sequel.lit('tab1') => [[:col1]],
                                Sequel.lit('tab2') => [[:col2]],
                                Sequel.lit('tab3') => [[:col3], [:col4]],
                                Sequel.lit('q.tab4') => [[:col5]]
                              })
    @db.extend_datasets do
      def supports_cte?
        true
      end
    end
    @db
  end

  def expect_columns(ds, *cols)
    _(ds.columns).must_equal(cols)
  end

  it 'should know columns from select * FROM tab' do
    expect_columns(db[:tab1], :col1)
  end

  it 'should know columns after append' do
    expect_columns(db[:tab1].select_append(Sequel.function(:min, :col1).as(:mini)), :col1, :mini)
  end

  it 'should know columns after select_all' do
    expect_columns(db[:tab1].select_all, :col1)
  end

  it 'should know columns after select_all(:tab1)' do
    expect_columns(db[:tab1].select_all(:tab1), :col1)
  end

  it 'should know columns after from_self' do
    expect_columns(db[:tab1].from_self, :col1)
  end

  it 'should know columns after a CTE' do
    ds = db[:cte1]
         .with(:cte1, db[:tab1])
    expect_columns(ds, :col1)
  end

  it 'should know columns after a JOIN' do
    ds = db[:tab1]
         .join(:tab2)
    expect_columns(ds, :col1, :col2)
  end

  it 'should know columns after a different kind of JOIN' do
    ds = db[:tab1]
         .join(db[:tab2])
    expect_columns(ds, :col1, :col2)
  end

  it 'should know columns from a JOIN and CTE' do
    ds = db[:tab1]
         .with(:cte1, db[:tab2])
         .join(db[:cte1])
    expect_columns(ds, :col1, :col2)
  end

  it 'should know columns from a select_all JOIN' do
    ds = db[:tab1]
         .join(db[:tab2], { Sequel[:tab1][:col1] => Sequel[:tab2][:col3] })
         .select_all(:tab1)
    expect_columns(ds, :col1)
  end

  it 'should know columns from an aliased select_all JOIN' do
    ds = db[:tab1].from_self(alias: :l)
                  .join(db[:tab2], { col3: :col1 })
                  .select_all(:l)
    expect_columns(ds, :col1)
  end

  it 'should know columns from an aliased select_all and added rhs column JOIN' do
    ds = db[:tab1].from_self(alias: :l)
                  .join(db[:tab2], { col3: :col1 }, table_alias: :r)
                  .select_all(:l)
                  .select_append(Sequel[:r][:col4])
    expect_columns(ds, :col1, :col4)
  end

  it 'should know columns from an aliased select_all rhs JOIN' do
    ds = db[:tab1].from_self(alias: :l)
                  .join(db[:tab2], { col3: :col1 }, table_alias: :r)
                  .select_all(:r)
    expect_columns(ds, :col2)
  end

  it 'should know columns from a directly aliased select_all rhs JOIN' do
    ds = db[:tab1].from_self(alias: :l)
                  .join(:tab2, { col3: :col1 }, table_alias: :r)
                  .select_all(:r)
    expect_columns(ds, :col2)
  end

  it 'should know columns from a a qualified JOIN' do
    ds = db[:tab1].from_self(alias: :l)
                  .join(Sequel[:q][:tab4], { col3: :col1 }, table_alias: :r)
                  .select_all(:r)
    expect_columns(ds, :col5)
  end
  it 'should remember columns from ctas' do
    db.create_table(:ctas_table, as: db.select(Sequel[1].as(:a)))
    ds = db[:ctas_table]
    expect_columns(ds, :a)
  end

  it 'should remember columns from create table' do
    db.create_table(:ddl_table) do
      String :a
    end
    ds = db[:ddl_table]
    expect_columns(ds, :a)
  end

  it 'should remember columns from view' do
    db.create_view(:ctas_view, db.select(Sequel[1].as(:a)))
    ds = db[:ctas_view]
    expect_columns(ds, :a)
  end

  it 'should ignore columns when asked, thus avoiding an issue with string-only SQL' do
    assert_raises { db.create_view(:ctas_view, 'SELECT 1 AS A') }
    db.create_view(:ctas_view, 'SELECT 1 AS A', dont_record: true)
  end
end
