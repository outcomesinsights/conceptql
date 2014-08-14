require_relative 'node'

module ConceptQL
  module Nodes
    # Represents a node that will create a date_range for every person in the database
    #
    # Accepts two params: start and end formateed as 'YYYY-MM-DD' or 'START' or 'END'
    # 'START' represents the first date of data in the data source,
    # 'END' represents the last date of data in the data source,
    class DateRange < Node
      def query(db)
        db.from(:person)
          .select_append(Sequel.cast('person', :text).as(:criterion_type))
          .select_append(Sequel.expr(:person_id).as(:criterion_id))
          .select_append(Sequel.expr(start_date(db)).cast(:date).as(:start_date),Sequel.expr(end_date(db)).cast(:date).as(:end_date)).from_self
      end

      def types
        [:person]
      end

      private
      def start_date(db)
        date_from(db, options[:start])
      end

      def end_date(db)
        date_from(db, options[:end])
      end

      # TODO: Select the earliest and latest dates of observation from
      # the proper CDM table to represent the start and end of data
      def date_from(db, str)
        return db.from(:visit_occurrence_with_dates).select { min(:start_date) } if str.upcase == 'START'
        return db.from(:visit_occurrence_with_dates).select { max(:end_date) } if str.upcase == 'END'
        return str
      end
    end
  end
end

