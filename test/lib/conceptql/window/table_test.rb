# frozen_string_literal: true

require_relative '../../../helper'

describe ConceptQL::Window::Table do
  describe '#selected_columns' do
    let(:db) { Sequel.mock(host: :postgres) }
    let(:window) do
      ConceptQL::Window::Table.new(
        window_table: :window_tbl,
        event_start_date_column: :start_date,
        event_end_date_column: :end_date
      )
    end

    it 'finds columns through AliasedExpression from from_self' do
      # Simulate what selectify produces: .select(*cols).from_self
      inner = db[:some_table].select(:person_id, :start_date, :end_date, :window_id)
      ds = inner.from_self

      cols = window.send(:selected_columns, ds)
      _(cols).must_equal(%i[person_id start_date end_date window_id])
    end

    it 'finds columns on dataset with explicit select' do
      ds = db[:some_table].select(:person_id, :start_date, :end_date)
      cols = window.send(:selected_columns, ds)
      _(cols).must_equal(%i[person_id start_date end_date])
    end

    it 'finds columns through nested Dataset in from' do
      inner = db[:some_table].select(:person_id, :start_date)
      ds = db.from(inner)
      cols = window.send(:selected_columns, ds)
      _(cols).must_equal(%i[person_id start_date])
    end

    it 'returns nil for bare table reference' do
      ds = db[:some_table]
      cols = window.send(:selected_columns, ds)
      _(cols).must_be_nil
    end
  end

  describe '#remove_window_id' do
    let(:db) { Sequel.mock(host: :postgres) }
    let(:window) do
      ConceptQL::Window::Table.new(
        window_table: :window_tbl,
        event_start_date_column: :start_date,
        event_end_date_column: :end_date
      )
    end

    it 'removes window_id from symbol columns without DB introspection' do
      inner = db[:some_table].select(:person_id, :start_date, :window_id)
      ds = inner.from_self

      result = window.send(:remove_window_id, ds)
      # The outer SELECT should not include window_id
      outer_select = result.opts[:select]
      _(outer_select).must_equal(%i[person_id start_date])
    end

    it 'removes window_id from expression columns without DB introspection' do
      # Simulate selectify output with cast expressions (like nullified columns)
      source_value_expr = Sequel.cast(nil, String).as(:source_value)
      inner = db[:some_table].select(
        :person_id,
        :start_date,
        source_value_expr,
        :window_id
      )
      ds = inner.from_self

      result = window.send(:remove_window_id, ds)
      outer_select = result.opts[:select]
      # Inner expressions are mapped to safe outer-scope symbol names
      _(outer_select).must_equal(%i[person_id start_date source_value])
    end

    it 'removes aliased window_id expression' do
      window_id_expr = Sequel.cast(nil, :Bigint).as(:window_id)
      inner = db[:some_table].select(:person_id, :start_date, window_id_expr)
      ds = inner.from_self

      result = window.send(:remove_window_id, ds)
      outer_select = result.opts[:select]
      _(outer_select).must_equal(%i[person_id start_date])
    end

    it 'handles from_self dataset referencing nonexistent table' do
      # This is the actual bug scenario: From operator with a temp table
      # that does not exist, wrapped in selectify's from_self
      inner = db[Sequel.qualify(:jigsaw_temp, :nonexistent_table)].select(
        :person_id, :criterion_id, :start_date, :end_date, :window_id
      )
      ds = inner.from_self

      # Should NOT trigger a DB query (columns! would fail on nonexistent table)
      result = window.send(:remove_window_id, ds)
      outer_select = result.opts[:select]
      _(outer_select).must_equal(%i[person_id criterion_id start_date end_date])
    end

    it 'preserves dataset when no window_id present' do
      inner = db[:some_table].select(:person_id, :start_date)
      ds = inner.from_self

      result = window.send(:remove_window_id, ds)
      outer_select = result.opts[:select]
      _(outer_select).must_equal(%i[person_id start_date])
    end
  end

  describe '#window_id_column?' do
    let(:window) do
      ConceptQL::Window::Table.new(
        window_table: :window_tbl,
        event_start_date_column: :start_date,
        event_end_date_column: :end_date
      )
    end

    it 'matches Symbol :window_id' do
      _(window.send(:window_id_column?, :window_id)).must_equal true
    end

    it 'does not match other symbols' do
      _(window.send(:window_id_column?, :person_id)).must_equal false
    end

    it 'matches AliasedExpression with window_id alias' do
      expr = Sequel.cast(nil, :Bigint).as(:window_id)
      _(window.send(:window_id_column?, expr)).must_equal true
    end

    it 'does not match AliasedExpression with other alias' do
      expr = Sequel.cast(nil, String).as(:source_value)
      _(window.send(:window_id_column?, expr)).must_equal false
    end

    it 'matches QualifiedIdentifier with window_id column' do
      expr = Sequel[:t][:window_id]
      _(window.send(:window_id_column?, expr)).must_equal true
    end

    it 'does not match QualifiedIdentifier with other column' do
      expr = Sequel[:t][:person_id]
      _(window.send(:window_id_column?, expr)).must_equal false
    end
  end
end
