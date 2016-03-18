require 'facets/array/recurse'
require 'facets/hash/deep_rekey'

module ConceptQL
  class FakeAnnotater
    attr :statement

    DOMAINS = {
      # Conditions
      condition: :condition_occurrence,
      primary_diagnosis: :condition_occurrence,
      icd9: :condition_occurrence,
      icd10: :condition_occurrence,
      condition_type: :condition_occurrence,
      medcode: :condition_occurrence,

      # Procedures
      procedure: :procedure_occurrence,
      cpt: :procedure_occurrence,
      drg: :procedure_occurrence,
      hcpcs: :procedure_occurrence,
      icd9_procedure: :procedure_occurrence,
      medcode_procedure: :procedure_occurrence,

      # Procedure Cost
      procedure_cost: :procedure_cost,

      # Visits
      visit_occurrence: :visit_occurrence,
      place_of_service_code: :visit_occurrence,

      # Person
      person: :person,
      gender: :person,
      race: :person,

      # Payer
      payer: :payer_plan_period,

      # Death
      death: :death,

      # Observation
      loinc: :observation,
      from_seer_visits: :observation,
      to_seer_visits: :observation,

      # Drug
      drug_exposure: :drug_exposure,
      rxnorm: :drug_exposure,
      drug_cost: :drug_cost,
      drug_type_concept_id: :drug_exposure,
      drug_type_concept: :drug_exposure,
      prodcode: :drug_exposure,

      # Date Operators
      date_range: :date,

      # Miscelaneous operators
      concept: :misc,
      vsac: :misc,
      numeric: :person,
      algorithm: :misc,
    }

    def initialize(statement)
      @statement = statement
    end

    def annotate
      traverse(statement)
    end

    def traverse(stmt)
      stmt.recurse(Array, Hash) do |arr_or_hash|
        if arr_or_hash.is_a?(Array)
          arr_or_hash.unshift(arr_or_hash.shift.to_sym)
          domains = DOMAINS[arr_or_hash.first.to_sym]
          unless domains
            domains = previous_domains(arr_or_hash)
          else
            domains = [domains].flatten
          end
          annotate_hash = if arr_or_hash.last.is_a?(Hash)
            arr_or_hash.last[:annotation] ||= {}
          else
            annotate_hash = {}
            arr_or_hash.push(annotation: annotate_hash)
            annotate_hash
          end
          annotate_hash[:counts] = {}
          domains.each do |domain|
            annotate_hash[:counts][domain] = {}
          end
          save_domains(arr_or_hash)
        else
          arr_or_hash.deep_rekey!
          arr_or_hash[:annotation] ||= {}
        end
        arr_or_hash
      end
    end

    def previous_domains(arr)
      extract = if arr.first == :recall
        [fetch_domains(arr[1])].compact
      elsif arr.last.is_a?(Hash) && arr.last[:left]
        [arr.last[:left]]
      else
        arr.select { |e| e.is_a?(Array) }
      end
      extract.map { |e| e.last[:annotation][:counts].keys }.flatten.compact.uniq
    end

    def fetch_domains(label)
      recorded_domains[label]
    end

    def save_domains(op)
      label = op.last[:label]
      return unless label
      recorded_domains[label] = op
    end

    def recorded_domains
      @recorded_domains ||= {}
    end
  end
end
