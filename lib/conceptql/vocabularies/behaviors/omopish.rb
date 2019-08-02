module ConceptQL
  module Vocabularies
    module Behaviors
      module Omopish
        # Overrides Operator#tables
        def tables
          domains
        end

        def where_clause(db)
          conds = { dm.source_vocabulary_id(domain) => vocabulary_id.to_i }
          conds[dm.source_value_column(domain)] = arguments_fix(db) unless select_all?
          conds
        end

        def query_cols
          dm.table_columns(domain)
        end

        def translated_vocabulary_id
          vocab_entry.omopv4_id
        end
      end
    end
  end
end

