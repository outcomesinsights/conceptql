require_relative 'operator'

module ConceptQL
  module Operators
    # Represents a operator that will grab all conditions that match the
    # condition type passed in
    #
    # Condition Type represents which position the condition held in
    # the raw data, e.g. primary inpatient header or 15th outpatient detail
    #
    # Multiple types can be specified at once
    class ConditionType < Operator
      register __FILE__, :omopv4

      desc 'Searches for conditions that match the given set of Condition Types'
      argument :condition_types, type: :codelist, vocab: 'Condition Type'
      category %(Occurrence Type)
      predominant_types :condition_occurrence
      query_columns :condition_occurrence
      validate_no_upstreams
      validate_at_least_one_argument

      def type
        :condition_occurrence
      end

      def query(db)
        db.from(:condition_occurrence)
          .where(condition_type_concept_id: condition_occurrence_type_concept_ids)
      end

    private
      def condition_occurrence_type_concept_ids
        arguments.map do |arg|
          to_concept_id(arg.to_s)
        end.flatten
      end

      def to_concept_id(ctype)
        ctype = ctype.to_s.downcase
        position = nil
        if ctype =~ /(\d|_primary)$/ && ctype.count('_') > 1
          parts = ctype.split('_')
          position = parts.pop.to_i
          position -= 1 if ctype =~ /^outpatient/
          ctype = parts.join('_')
        end
        retval = concept_ids[ctype.to_sym]
        return retval[position] if position
        return retval
      end

      def concept_ids
        @concept_ids ||= begin
          hash = {
            inpatient_detail: (38000183..38000198).to_a,
            inpatient_header: (38000199..38000214).to_a,
            outpatient_detail: (38000215..38000229).to_a,
            outpatient_header: (38000230..38000244).to_a,
            ehr_problem_list: [38000245],
            condition_era_0_day_window: [38000246],
            condition_era_30_day_window: [38000247]
          }
          hash[:primary] = %w(inpatient_detail inpatient_header outpatient_detail outpatient_header).map { |w| hash[w.to_sym].first }
          hash[:outpatient_primary] = %w(outpatient_detail outpatient_header).map { |w| hash[w.to_sym].first }
          hash[:inpatient_primary] = %w(inpatient_detail inpatient_header).map { |w| hash[w.to_sym].first }
          hash[:inpatient] = hash[:inpatient_detail] + hash[:inpatient_header]
          hash[:outpatient] = hash[:outpatient_detail] + hash[:outpatient_header]
          hash[:condition_era] = hash[:condition_era_0_day_window] + hash[:condition_era_30_day_window]
          hash
        end
      end
    end
  end
end

