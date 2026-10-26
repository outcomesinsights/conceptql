# frozen_string_literal: true

require_relative "operator"

module ConceptQL
  module Operators
    # The base class of operators whose domains and columns are those of their
    # upstreams (union, count, sum, numeric, dedup, episode, time_window and
    # co_reported). It has no query method, so it does not register: pass_thru
    # is not an operator name.
    class PassThru < Operator
      basic_type :set
      no_desc

      def domains(db)
        doms = upstreams.compact.flat_map { |up| up.domains(db) }.uniq
        doms.empty? ? [ :invalid ] : doms
      end

      def query_cols
        upstreams.map(&:query_cols).inject(:|)
      end
    end
  end
end
