require_relative 'temporal_operator'

module ConceptQL
  module Operators
    class StartedBy < TemporalOperator
      register __FILE__
      desc <<-EOF
If a result in the left hand results (LHR) has the same start_date and the same or a later end_date as a result in the right hand results (RHR), it is passed through.
L----Y----L
R-------R
L--N--L
      EOF
      def where_clause
        Sequel.&({Sequel[:l][:start_date] => Sequel[:r][:start_date]}, Sequel[:l][:end_date].send(inclusive? ? :>= : :>, Sequel[:r][:end_date])) 
      end
    end
  end
end
