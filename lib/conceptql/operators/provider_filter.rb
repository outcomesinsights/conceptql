require_relative 'operator'

module ConceptQL
  module Operators
    # Filters incoming events to only those that have been associated with
    # providers matching the given criteria.
    class ProviderFilter < Operator
      register __FILE__

      desc "Filters incoming events to only those that match the associated providers based on provider specialty concept_ids."
      option :specialties, type: :string
      category "Filter Single Stream"
      basic_type :temporal
      allows_one_upstream
      validate_one_upstream
      validate_required_options :specialties
      require_column :specialty_concept_id
      default_query_columns

      def query(db)
        ds = stream.evaluate(db).from_self(alias: :upstream)

        specialty_concept_ids = options[:specialties].split(/\s*,\s*/)
            
        unless specialty_concept_ids.include?('*')
          ds = ds.where(specialty_concept_id: specialty_concept_ids.map(&:to_i))
        end

        ds
      end

      def query_columns
        default_columns + [:specialty_concept_id]
      end
    end
  end
end


