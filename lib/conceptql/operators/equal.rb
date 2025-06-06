# frozen_string_literal: true

require_relative 'temporal_operator'

module ConceptQL
  module Operators
    class Equal < TemporalOperator
      register __FILE__

      desc 'For each person, passes along left hand records that have the same value_as_number as a right hand record.'

      require_column :value_as_number

      def where_clause
        { Sequel[:r][:value_as_number] => Sequel[:l][:value_as_number] }
      end
    end
  end
end
