require_relative 'temporal_node'

module ConceptQL
  module Nodes
    class Contains < TemporalNode
      desc <<-EOF
Any result in the LHR whose start_date is on or before and whose end_date is on or after a result from the RHR.
L--X-L
R-----R
L------Y--------L
EOF
      def where_clause
        [Proc.new { l__start_date <= r__start_date}, Proc.new { r__end_date <= l__end_date }]
      end
    end
  end
end
