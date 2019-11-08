require_relative "base"

module ConceptQL
  module Operators
    module PassThru
      class Union < Base
        register __FILE__

        class Combiner
          attr_reader :combinables

          def initialize(combinables)
            @combinables = combinables
          end

          def queries(db)
            combinables.group_by(&:domain).map do |domain, combos|
              include_uuid = combos.any? { |c| c.options[:uuid] }
              criteria = combos.map do |combo|
                combo.filter_clause(db)
              end.inject(&:|)

              table = combos.first.criterion_table
              ds = db[table]
                .where(criteria)
              combos.first.select_it(ds, specific_table: table, domain: domain, uuid: include_uuid)
            end
          end
        end

        desc 'Pools sets of incoming results into a single large set of results.'
        allows_many_upstreams
        category "Combine Streams"
        default_query_columns
        validate_at_least_one_upstream
        validate_no_arguments

        def query(db)
          combinables, individuals = upstreams.partition { |upstream| upstream.is_a?(Vocabulary) }

          queries = individuals.map do |expression|
            expression.evaluate(db)
          end

          queries += Combiner.new(combinables).queries(db)

          queries.map!{|ds| ds.from_self.select(*query_cols).from_self}
          queries.inject do |q, query|
            q.union(query, all: true)
          end
        end
      end
    end
  end
end
