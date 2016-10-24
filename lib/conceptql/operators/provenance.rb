require_relative 'operator'

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

      desc "Filters incoming events to only those that match the provenances."
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
        @concept_ids ||= Psych.load_file(config_dir + 'provenance.yml')
      end

      def config_dir
        Pathname.new(__FILE__).dirname + '..' + '..' + '..' + 'config'
      end
    end
  end
end


