# frozen-string-literal: true
#
# The columns_introspection extension attempts to introspect the
# selected columns for a dataset before issuing a query.  If it
# thinks it can guess correctly at the columns the query will use,
# it will return the columns without issuing a database query.
#
# This method is not fool-proof, it's possible that some databases
# will use column names that Sequel does not expect.  Also, it
# may not correctly handle all cases. 
#
# To attempt to introspect columns for a single dataset:
#
#   ds = ds.extension(:columns_introspection)
#
# To attempt to introspect columns for all datasets on a single database:
#
#   DB.extension(:columns_introspection)
#
# Related module: Sequel::ColumnsIntrospection

#
module Sequel
  class ColyTracker
    PASS_THRU_COLUMNS = proc do |hash, key|
      hash[key.to_sym] = Sequel.expr(key.to_sym)
    end

    attr_reader :qualifier

    def initialize(default_proc = PASS_THRU_COLUMNS)
      @columns = {}
      @columns.default_proc = default_proc
      @qualifier = Sequel
    end

    def add_column(name, definition)
      add_columns(name => definition)
    end

    def add_columns(columns)
      @columns = @columns.merge(columns)
    end

    def qualify_columns(qualifier)
      @qualifier = Sequel[qualifier]
    end

    def allow_comments?
      ENV["CONCEPTQL_ENABLE_COMMENTS"] == "true"
    end

    def has_column?(column_name)
      @columns.has_key?(column_name)
    end

    def auto_columns(opts = {})
      if more_cols = opts[:additional_columns]
        add_columns(more_cols)
      end

      required_columns = opts.fetch(:required_columns)

      required_columns.map do |required_column|
        target_col = @columns[required_column]
        target_col = 
          case target_col
          when Sequel::SQL::Identifier, Symbol
            qualifier[target_col]
          when Proc
            target_col.call(qualifier)
          else
            target_col
          end
        target_col.as(required_column)
      end
    end
  end

  module Coly
    def self.extended(db)
      db.extend_datasets(ColyDatasetMethods)
    end
  end

  module ColyDatasetMethods
    PASS_THRU_COLUMNS = proc do |hash, key|
      hash[key.to_sym] = Sequel.expr(key.to_sym)
    end

    def auto_column(name, definition)
      auto_columns(name => definition)
    end

    def auto_columns(columns)
      clone(auto_columns: (opts[:auto_columns] || {}).merge(columns))
    end

    def auto_qualify(qualifier)
      clone(auto_qualify: Sequel[qualifier])
    end

    def from_self(opts = {})
      c = super(opts)
      c = c.auto_qualify(opts[:alias]) if opts[:alias]
      c
    end

    def select(*args)
      super
    end

    def auto_select(opts = {})
      select(*_auto_columns(opts))
        .from_self({alias: opts[:alias]})
    end

    def has_auto_column?(column_name)
      opts[:auto_columns] && opts[:auto_columns].has_key?(column_name)
    end

    def _auto_columns(opts = {})
      if more_cols = opts[:additional_columns]
        add_columns(more_cols)
      end

      required_columns = opts.fetch(:required_columns)

      cols = self.opts[:auto_columns] || {}
      cols.default_proc = PASS_THRU_COLUMNS
      qualifier = self.opts[:auto_qualify] || Sequel
      required_columns.map do |required_column|
        target_col = cols[required_column]
        target_col = 
          case target_col
          when Sequel::SQL::Identifier, Symbol
            qualifier[target_col]
          when Proc
            target_col.call(qualifier)
          else
            target_col
          end
        target_col.as(required_column)
      end
    end
  end

  Database.register_extension(:coly, Sequel::Coly)
end

