# frozen_string_literal: true

require_relative "pass_thru"

module ConceptQL
  module Operators
    class Union < PassThru
      register __FILE__
      effects :combine

      class Combiner
        attr_reader :combinables

        # The vocabulary leaves that one scan can select, in groups: the
        # leaves of one domain and one column family. The scan takes its
        # columns from its first leaf, so a leaf with the lab columns (read,
        # whose domain is condition_occurrence) gets its own scan, and an icd9
        # leaf beside it keeps the default columns (bead conceptql-qdn9).
        def self.scans(combinables)
          combinables.group_by { |combo| [ combo.domain, combo.column_family ] }.values
        end

        def initialize(combinables)
          @combinables = combinables
        end

        def queries(db)
          self.class.scans(combinables).map do |combos|
            domain = combos.first.domain
            include_uuid = combos.any? { |c| c.options[:uuid] }
            criteria = combos.map do |combo|
              combo.filter_clause(db)
            end.inject(&:|)

            criteria = Sequel.&(vocabularies_in(combos), criteria) if combos.length > 1

            table = combos.first.criterion_table
            ds = db[table]
                 .where(criteria)
            combos.first.select_it(ds, specific_table: table, domain: domain, uuid: include_uuid)
          end
        end

        private

        # Every OR'd criterion already requires its own vocabulary, so this IN
        # list selects no new rows and drops none. It is explicit because a
        # plain OR stopped DuckDB's Parquet filter pushdown (bead conceptql-agx).
        def vocabularies_in(combos)
          conditions = combos.map(&:vocabulary_condition)
          columns = conditions.flat_map(&:keys).uniq
          raise "Merged vocabularies use more than one vocabulary column: #{columns}" unless columns.length == 1

          { columns.first => conditions.map { |c| c[columns.first] }.uniq }
        end
      end

      def events_per_patient
        upstreams.all? { |u| u.events_per_patient == :single } ? :single : :multiple
      end

      def multiple_vocabularies
        return true if upstreams.any?(&:multiple_vocabularies)

        vocabularies.length > 1
      end

      desc "Combines the records of all its upstream operators into one stream. " \
           "Each record keeps its own type, so one stream can hold several types."

      returns "Each record of each upstream. A record that comes from more than one upstream comes out once. " \
              "Two records are the same only when every column is equal, including label."

      example "Two streams of the same type (condition_occurrence) combined into one stream",
              [ "union", [ "icd9", "412" ], [ "icd9", "250.01" ] ]
      example "Two condition_occurrence streams combined, then combined with a procedure_occurrence stream",
              [ "union", [ "union", [ "icd9", "412" ], [ "icd9", "250.01" ] ], [ "cpt", "99214" ] ]
      example "Two condition_occurrence streams and a procedure_occurrence stream combined by a single union",
              [ "union", [ "icd9", "412" ], [ "icd9", "250.01" ], [ "cpt", "99214" ] ]

      category "Combine Streams"
      default_query_columns
      validate_at_least_one_upstream
      validate_at_least_two_upstreams
      validate_no_arguments

      def query(db)
        combinables, individuals = upstreams.partition { |upstream| upstream.is_a?(Vocabulary) }

        queries = individuals.map do |expression|
          expression.evaluate(db)
        end

        queries += Combiner.new(combinables).queries(db)

        all = disjoint_upstreams?
        queries.map! { |ds| ds.from_self.select(*query_cols).from_self }
        queries.inject do |q, query|
          q.union(query, all: all)
        end
      end

      # The (criterion_domain, vocabulary condition) pairs of every row this
      # union can emit, or nil when an upstream does not fix them at build
      # time. See #disjoint_upstreams?.
      def branches
        upstream_branches = upstreams.map { |upstream| branches_of(upstream) }
        upstream_branches.flatten(1) if upstream_branches.all?
      end

      private

      # Every stream is a set (seed conceptql-0eb), so union removes the rows
      # that arrive from more than one upstream: UNION, not UNION ALL. The
      # duplicate removal is expensive on large data (conceptql-5pz), so union
      # skips it when no row can arrive from two of its queries. It proves
      # that only for vocabulary operators, cpt_or_hcpcs-style operators and
      # unions of them, because each of their rows carries the operator's
      # domain as criterion_domain and comes from a row of its vocabulary.
      # Two rows with different domains differ, and so do two rows of one
      # domain (one table) from different vocabularies of one column. Any
      # other upstream can overlap anything, so union removes duplicates.
      def disjoint_upstreams?
        combinables, individuals = upstreams.partition { |upstream| upstream.is_a?(Vocabulary) }
        queries = individuals.map { |upstream| branches_of(upstream) }
        queries += Combiner.scans(combinables).map { |combos| combos.flat_map { |c| branches_of(c) } }
        return false unless queries.all?

        queries.combination(2).all? do |one, other|
          one.product(other).all? { |a, b| disjoint_branches?(a, b) }
        end
      end

      def branches_of(upstream)
        case upstream
        when Vocabulary then [ [ upstream.domain, upstream.vocabulary_condition ] ]
        when MultipleVocabularies then upstream.vocab_ops.flat_map { |vo| branches_of(vo) }
        when Union then upstream.branches
        end
      end

      def disjoint_branches?((domain, condition), (other_domain, other_condition))
        domain != other_domain || (condition.keys == other_condition.keys && condition != other_condition)
      end
    end
  end
end
