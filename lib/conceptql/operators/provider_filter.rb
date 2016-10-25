require_relative 'operator'

module ConceptQL
  module Operators
    # Filters incoming events to only those that have been associated with
    # providers matching the given criteria.
    class ProviderFilter < Operator
      register __FILE__

      desc "Filters incoming events to only those that match the associated providers."
      option :specialties, type: :codelist, vocab: "Specialty"
      category "Filter Single Stream"
      basic_type :temporal
      allows_one_upstream
      validate_one_upstream
      validate_required_options :specialties
      require_column :provider_id
      default_query_columns

      def query(db)
        db.from(stream.evaluate(db))
          .where(provider_id: matching_provider_ids(db))
      end

    private
      def matching_provider_ids(db)
        specialty_concept_ids = options[:specialties].split(/\s*,\s*/).map(&:to_i)
        db.from(:provider)
          .where(specialty_concept_id: specialty_concept_ids)
          .select(:provider_id)
      end
    end
  end
end


