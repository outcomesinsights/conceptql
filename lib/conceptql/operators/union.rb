require_relative 'pass_thru'

module ConceptQL
  module Operators
    class Union < PassThru
      register __FILE__

      desc 'Pools sets of incoming results into a single large set of results.'
      allows_many_upstreams
      category "Combine Streams"
      default_query_columns
      validate_at_least_one_upstream
      validate_no_arguments

      def query(db)
        datasets = upstreams.map do |expression|
          expression.evaluate(db)
        end

        optss = datasets
          .map { |ds| ds.opts.compact }
          .each { |opts| opts.delete(:num_dataset_sources) }

        possibly_combinable = optss.all? { |opts| opts.length == 1 && opts[:from].length == 1 }
        if possibly_combinable
          subqueries = optss.map { |opts| opts[:from].first }
          subqueries.map! { |ds| ds.is_a?(Sequel::SQL::AliasedExpression) ? ds.expression : ds }
          subquery_optss = subqueries.map { |ds| ds.opts.compact }
          subquery_optss.each{|opts| opts.delete(:where)}
          combinable = subquery_optss.uniq.length == 1
        end

        if combinable
          first = subqueries.shift
          first
            .or(Sequel.|(*subqueries.map{|ds| ds.opts[:where] || true}))
            .from_self
        else
          datasets.map!{|ds| ds.from_self.select(*query_cols)}
          datasets.inject do |q, query|
            q.union(query, all: true)
          end
        end
      end

      def flattened
        exprs = []
        upstreams.each do |x|
          if x.is_a?(Union)
            exprs.concat x.flattened.upstreams
          else
            exprs << x
          end
        end
        dup_values(exprs)
      end

      def optimized
        first, *rest = flattened.upstreams
        exprs = [first]

        rest.each do |expression|
          add = true
          exprs.length.times do |i|
            exp = exprs[i]
            if exprs[i].unionable?(expression)
              exprs[i] = exp.union(expression, all: true)
              add = false
              break
            end
          end
          exprs << expression if add
        end

        dup_values(exprs.map{|x| x.is_a?(Operator) ? x.optimized : x})
      end
    end
  end
end
