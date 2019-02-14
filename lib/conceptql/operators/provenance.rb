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

      desc <<-EOF
Filters incoming events to those with the indicated provenance.

Enter numeric concept id(s), or the corresponding text label(s):
- Inpatient: inpatient, inpatient_detail, inpatient_header, inpatient_primary, inpatient_primary_or_first
- Outpatient: outpatient, outpatient_detail, outpatient_header, outpatient_primary, outpatient_primary_or_first
- Carrier: carrier_claim, carrier_claim_detail, carrier_claim_header, carrier_claim_primary_or_first
- Other: primary, primary_or_first, claim
      EOF
      argument :provenance_types, label: 'Provenance Types', type: :codelist
      category "Filter Single Stream"
      basic_type :temporal
      allows_one_upstream
      validate_one_upstream
      default_query_columns

      include ConceptQL::Provenanceable

      def query(db)
        db.from(stream.evaluate(db)).where(build_where_from_codes(arguments))
      end

    private

      def validate(db, opts = {})
        super
        # TODO
      end
    end
  end
end


