require_relative "base"

module ConceptQL
  module Operators
    module PassThru
      # Represents a operator that will either:
      # - create a lab_value_as_number value for every person in the database
      # - change the lab_value_as_number value for every every result passed in
      #   - either to a number
      #   - or a value from a column in the origin row
      #
      # Accepts two params:
      # - Either a number value or a symbol representing a column name
      # - An optional stream
      class Numeric < Base
        include ConceptQL::Behaviors::Windowable
        include ConceptQL::Behaviors::Timeless
        include ConceptQL::Behaviors::Selectable

        register __FILE__

        desc <<-EOF
Represents an operator that will either:
- Create a lab_value_as_number value for every person in the database
- Change the lab_value_as_number value for every result passed in
  - Either to a number
  - Or a value from a column in the origin row

Accepts two params:
- Either a number value or a symbol representing a column name
- An optional stream
        EOF
        argument :value, type: :float
        allows_one_upstream
        validate_at_most_one_upstream
        validate_one_argument
        default_query_columns
        output_column :lab_value_as_number

        def query(db)
          ds = is_selection? ? as_criterion(db) : upstream_query(db)
          ds.auto_column(:lab_value_as_number, numeric_literal)
        end

        def domains(db)
          is_selection? ? [:person] : super
        end

        def required_columns_for_upstream
          super - %i[lab_value_as_number]
        end

        def skip_windows?
          !is_selection?
        end

        def is_selection?
          stream.nil?
        end

        private

        def as_criterion(db)
          # TODO: This call to auto_column is a hack
          # This operator acts as a PassThru and a Selection
          # so we really need to get the Selection part from
          # Selection::Base
          make_selectable(db[dm.nschema.patients.view.name])
        end

        def numeric_literal
          value = arguments.first.to_s.strip
          value = nil if value.blank?
          if !value || is_a_number?(value)
            Sequel.cast_numeric(value, Float)
          else
            Sequel.identifier(value)
          end
        end

        def is_a_number?(value)
          value =~ /\A[-+]?[0-9]*\.?[0-9]+\Z/
        end
      end
    end
  end
end
