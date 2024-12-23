require 'active_support/core_ext/object/try'
# frozen-string-literal: true

module Sequel
  module ColdColDatabase
    def self.extended(db)
      db.extend_datasets(ColdColDataset)
      db.instance_variable_set(:@created_tables, {})
      db.instance_variable_set(:@created_views, {})
    end

    def load_schema(path)
      schemas = Psych.load_file(path).map do |table, info|
        columns = info[:columns].map { |column_name, col_info| [column_name, col_info] }
        [literal(table), columns]
      end.to_h
      schemas = (instance_variable_get(:@schemas) || {}).merge(schemas)
      instance_variable_set(:@schemas, schemas)
    end

    def add_table_schema(name, info)
      instance_variable_get(:@schemas)[literal(name)] = info
    end

    def create_table_as(name, sql, options = {})
      super.tap do |o|
        record_table(name, columns_from_sql(sql))
      end
    end

    def create_table_sql(name, generator, options)
      super.tap do |o|
        record_table(name, columns_from_generator(generator))
      end
    end

    def create_view_sql(name, source, options)
      super.tap do |o|
        record_view(name, columns_from_sql(source)) unless options[:dont_record]
      end
    end

    def record_table(name, columns)
      name = literal(name)
      # puts "recording table #{name}"
      Sequel.synchronize { @created_tables[name] = columns }
    end

    def record_view(name, columns)
      name = literal(name)
      # puts "recording view #{name}"
      Sequel.synchronize { @created_views[name] = columns }
    end

    def columns_from_sql(sql)
      sql.columns
    end

    def columns_from_generator(generator)
      generator.columns.map { |c| [c[:name], c] }
    end
  end

  module ColdColDataset
    def columns
      columns_search
    end

    def columns_search(opts_chain = nil)
      if (cols = _columns)
        return cols
      end

      unless (pcs = probable_columns(opts.merge(parent_opts: opts_chain))) && pcs.all?
        raise("Failed to find columns for #{sql}")
      end

      self.columns = pcs
    end

    protected

    WILDCARD = Sequel.lit('*').freeze

    def probable_columns(opts_chain)
      if !(cols = opts[:select]).blank?
        from_stars = []

        if has_select_all?(cols)
          from_stars = (opts[:from] || []).flat_map { |from| fetch_columns(from, opts_chain) }
          cols = cols.reject { |c| c == WILDCARD }
        end

        from_stars += cols
                      .select { |c| c.is_a?(Sequel::SQL::ColumnAll) }
                      .flat_map { |c| from_named_sources(c.table.to_sym, opts_chain) }

        cols = cols.reject { |c| c.is_a?(Sequel::SQL::ColumnAll) }

        (from_stars + cols.map { |c| probable_column_name(c) }).flatten
      else
        froms = opts[:from] || []
        joins = (opts[:join] || []).map(&:table_expr)
        (froms + joins).flat_map { |from| fetch_columns(from, opts_chain) }
      end
    end

    private

    def has_select_all?(cols)
      cols.any? { |c| c == WILDCARD }
    end

    def from_named_sources(name, opts_chain)
      current_opts = opts_chain

      from = (opts[:from] || [])
             .select { |f| f.is_a?(Sequel::SQL::AliasedExpression) }
             .detect { |f| literal(f.alias) == literal(name) }

      return from.expression.columns_search(opts_chain) if from

      with = nil

      while current_opts.present? && with.blank?
        with = (current_opts[:with] || []).detect { |wh| literal(wh[:name]) == literal(name) }
        current_opts = current_opts[:parent_opts]
      end

      return with[:dataset].columns_search(opts_chain) if with

      if (join = (opts[:join] || []).detect { |jc| literal(jc.table_expr.try(:alias)) == literal(name) })
        join_expr = join.table_expr.expression
        return join_expr.columns_search(opts_chain) if join_expr.is_a?(Sequel::Dataset)

        name = join_expr
      end

      created_views = db.instance_variable_get(:@created_views) || {}
      created_tables = db.instance_variable_get(:@created_tables) || {}
      schemas = db.instance_variable_get(:@schemas)
      [created_views, created_tables, schemas].each do |known_columns|
        if known_columns && (table = literal(name)) && (sch = Sequel.synchronize { known_columns[table] })
          return sch.map { |c, _| c }
        end
      end

      pp name
      pp opts_chain
      pp sql
      raise("Failed to find columns for #{literal(name)}")
    end

    def fetch_columns(from, opts_chain)
      from = from.expression if from.is_a?(SQL::AliasedExpression)

      case from
      when Dataset
        from.columns_search(opts_chain)
      when Symbol, SQL::Identifier, SQL::QualifiedIdentifier
        from_named_sources(from, opts_chain)
      end
    end

    # Return the probable name of the column, or nil if one
    # cannot be determined.
    def probable_column_name(c)
      case c
      when Symbol
        _, c, a = split_symbol(c)
        (a || c).to_sym
      when SQL::Identifier
        c.value.to_sym
      when SQL::QualifiedIdentifier
        c.column.to_sym
      when SQL::AliasedExpression
        a = c.alias
        a.is_a?(SQL::Identifier) ? a.value.to_sym : a.to_sym
      end
    end
  end

  Database.register_extension(:cold_col, Sequel::ColdColDatabase)
end
