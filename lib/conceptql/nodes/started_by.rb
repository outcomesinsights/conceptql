require_relative 'temporal_node'

module ConceptQL
  module Nodes
    class StartedBy < TemporalNode
      desc <<-EOF
If LHR has the same start date as RHR, but LHR's end_date falls on or after end_date of RHR, LHR is passed through.
L----Y----L
R-------R
L--N--L
      EOF
      def where_clause
        [ { l__start_date: :r__start_date } ] + \
        if inclusive?
          [ Proc.new { l__end_date >= r__end_date } ]
        else
          [ Proc.new { l__end_date > r__end_date } ]
        end
      end
    end
  end
end
