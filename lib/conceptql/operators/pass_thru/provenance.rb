require_relative "base"

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
    class Provenance < Base
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

      include ConceptQL::Provenanceable

      def query(db)
        limit_to_provenance(upstream_query(db), arguments)
      end

    private

      def additional_validation(db, opts = {})
        build_std_code_concept_ids(arguments)

        bad_keywords = arguments.each_with_object({file: [], code: []}){|c,h|

          file_type = file_provenance_part_from_code(c)
          code_type = code_provenance_part_from_code(c)

          h[:file] << file_type if file_type.to_i.zero? && !file_type.nil? && !allowed_file_provenance_types.include?(file_type)
          h[:code] << code_type if code_type.to_i.zero? && !code_type.nil? && !allowed_code_provenance_types.include?(code_type)
        }

        warn_keywords = arguments.each_with_object([]){|c,h|
          file_type = file_provenance_part_from_code(c)
          code_type = code_provenance_part_from_code(c)

          h << file_type if !file_type.to_i.zero?
          h << code_type if !code_type.to_i.zero?
        }

        add_error("unrecognized file type keywords", *bad_keywords[:file].uniq) if bad_keywords[:file].present?
        add_error("unrecognized code type keywords", *bad_keywords[:code].uniq) if bad_keywords[:code].present?
        add_warning("concept ids are not checked", *warn_keywords) if warn_keywords.present?
      end
    end
  end
end


