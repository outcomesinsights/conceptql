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
Filters incoming events to those with the indicated provenance.

Enter numeric concept id(s), or the corresponding text label(s)
(e.g., "inpatient", "outpatient", "carrier_claim").
      EOF
      argument :provenance_types, label: 'Provenance Types', type: :codelist
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

      def validate(db, opts = {})
        super
        bad_keywords = all_args.select { |arg| arg.to_i.zero? }
                        .reject { |arg| concept_ids.keys.include?(arg.to_sym) }

        if ConceptQL::Utils.present?(bad_keywords)
          add_error("unrecognized keywords", *bad_keywords)
        end
      end

      def provenance_concept_ids
        all_args.flat_map do |arg|
          to_concept_id(arg)
        end
      end

      def all_args
        arguments.map(&:to_s).flat_map { |w| w.split(/\s*,\s*/) }.uniq
      end
    end
  end
end


