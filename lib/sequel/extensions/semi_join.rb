# frozen-string-literal: true

module Sequel
  module SemiJoin
    def self.extended(db)
      db.extend_datasets(SemiJoinDatasetMethods)
    end

    module SemiJoinDatasetMethods
      def semi_join(table, *exprs)
        opts = exprs.pop if exprs.last.is_a?(Hash)
        exprs = exprs.pop
        exprs, opts = opts, {}  if exprs.nil?

        table = Sequel[table] if table.is_a?(Symbol)
        table = table.as(opts[:table_alias]) if opts[:table_alias]

        where_clause = db[table]
          .select(1)
          .where(exprs)
          .exists

        where(where_clause)
      end
    end
  end

  Database.register_extension(:semi_join, Sequel::SemiJoin)
end

