require_relative 'operator'

module ConceptQL
  module Operators
    # Represents a operator that will create a date_range for every person in the database
    #
    # Accepts two params: start and end formateed as 'YYYY-MM-DD' or 'START' or 'END'
    # 'START' represents the first date of data in the data source,
    # 'END' represents the last date of data in the data source,
    class DateRange < Operator
      register __FILE__, :omopv4

      desc 'Used to represent a date literal.'
      option :start, type: :string
      option :end, type: :string
      category %(Temporal Manipulation)

      def query(db)
        db.from(:person)
          .select_append(Sequel.cast_string('person').as(:criterion_type))
          .select_append(Sequel.expr(:person_id).as(:criterion_id))
          .select_append(Sequel.as(start_date(db), :start_date), Sequel.as(end_date(db), :end_date)).from_self
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
        return db.from(:observation_period).get { min(:observation_period_start_date) } if str.upcase == 'START'
        return db.from(:observation_period).get { max(:observation_period_end_date) } if str.upcase == 'END'
        return Sequel.lit('CONVERT(DATETIME, ?)', str) if db.database_type == :mssql
        return Sequel.lit('CAST(? as TIMESTAMP)', str) if db.database_type == :impala
        return Sequel.lit('date ?', str)
      end
    end
  end
end

