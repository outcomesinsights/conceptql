# frozen_string_literal: true

require_relative "pass_thru"

module ConceptQL
  module Operators
    class Sum < PassThru
      register __FILE__

      def events_per_patient
        group_by_person? ? :single : :multiple
      end

      # A person result per person, as the person cast gives (seed conceptql-6c3)
      def domains(db)
        group_by_person? ? [ :person ] : super
      end

      def multiple_vocabularies
        return true if upstreams.any?(&:multiple_vocabularies)

        vocabularies.length > 1
      end

      desc <<~EOF
        Sums value_as_number across all records that match on all but start_date, end_date.
        For start_date and end_date the min and max of each respectively is returned.
        With group_by_person, sums all of the records of each person into one person record.
      EOF
      option :group_by_person, type: :boolean,
                               instructions: "Choose whether to sum all of the records of each person into one person record, for example to count the events of each person"
      default_query_columns
      validate_at_least_one_upstream
      validate_no_arguments
      # The editor's checkbox sends true or false, and an unset field nil
      validate_option ->(value) { [ true, false, nil ].include?(value) }, :group_by_person
      require_column :value_as_number

      def query(db)
        return per_person_query(db) if group_by_person?

        db.from(unioned(db))
          .select_group(*(dynamic_columns - %i[start_date end_date criterion_id value_as_number]))
          .select_append(Sequel.lit("?", 0).as(:criterion_id))
          .select_append { min(start_date).as(:start_date) }
          .select_append { max(end_date).as(:end_date) }
          .select_append { sum(value_as_number).as(:value_as_number) }
          .from_self
      end

      # One row for each person (and window): the earliest start_date, the
      # latest end_date and the sum of value_as_number. criterion_table,
      # criterion_domain and column_family are those of the person cast. No
      # single record stands behind the row, so criterion_id is 0 and the
      # other columns are NULL.
      def per_person_query(db)
        person = {
          criterion_id: Sequel.lit("?", 0),
          criterion_table: Sequel.cast_string(dm.table_by_domain(:person).to_s),
          criterion_domain: Sequel.cast_string("person"),
          column_family: Sequel.cast_string(ConceptQL::Scope::DEFAULT_COLUMN_FAMILY)
        }
        aggregated = %i[start_date end_date value_as_number]
        nulls = dynamic_columns - matching_columns - person.keys - aggregated

        db.from(unioned(db))
          .select_group(*matching_columns)
          .select_append(*person.map { |column, value| value.as(column) })
          .select_append { min(start_date).as(:start_date) }
          .select_append { max(end_date).as(:end_date) }
          .select_append { sum(value_as_number).as(:value_as_number) }
          .select_append(*nulls.map { |column| rdbms.process(column, nil) })
          .from_self
      end

      def group_by_person?
        options[:group_by_person]
      end

      def unioned(db)
        upstreams.map { |c| c.evaluate(db).select(*query_cols) }.inject do |uni, q|
          uni.union(q.from_self)
        end
      end
    end
  end
end
