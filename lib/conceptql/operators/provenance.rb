require_relative 'operator'
require_relative '../behaviors/provenanceable'

module ConceptQL
  module Operators
    # Filters the incoming stream of events to only those that have a
    # provenance-related concept_id.
    #
    # Provenance related concepts are the ones found in the xxx_type_concept_id
    # field.
    #
    # If the event has NULL for the provenance-related field, they are filtered
    # out.
    #
    # Multiple provenances can be specified at once
    class Provenance < Operator
      register __FILE__

      include ConceptQL::Provenanceable

      desc <<-EOF
Filters incoming events to those matching the indicated provenance. Enter the
numeric concept id(s) for the provenance, or the corresponding text label(s)
(e.g., "inpatient", "outpatient", "carrier", etc.). Separate entries with commas."
      EOF
      argument :provenance_types, label: 'Provenance Types', type: :string
      category "Filter Single Stream"
      basic_type :temporal
      allows_one_upstream
      validate_one_upstream
      require_column :provenance_type
      default_query_columns

      def query(db)
        db.from(stream.evaluate(db))
          .where(provenance_type: provenance_concept_ids)
      end

    private
      def provenance_concept_ids
        arguments.map do |arg|
          to_concept_id(arg.to_s)
        end.flatten
      end
    end
  end
end


