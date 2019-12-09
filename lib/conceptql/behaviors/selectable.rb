module ConceptQL
  module Behaviors
    module Selectable
=begin
      def default_columns_proc
        proc do |hash, key|
          hash[key] = rdbms.cast_it(key, nil)
        end
      end

      def available_columns
        super.merge(dm.columns_by_table(table, schema: table_alias, criterion_domain: domain))
      end
=end
    end
  end
end
