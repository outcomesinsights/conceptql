require "psych"

module ConceptQL
  module DataModel
    class Base
      SCHEMAS = Pathname.glob(ConceptQL.schemas_dir + "*").each_with_object({}) do |schema_dir, schemas|
        data_model = File.basename(schema_dir)
        schemas[data_model.to_sym] = Psych.load_file(schema_dir + "schema.yml")
        schemas[("#{data_model}_arrayed").to_sym] = Psych.load_file(schema_dir + "schema_arrayed.yml")
      end

      attr_reader :rdbms, :lexicon

      def initialize(opts = {})
        @rdbms = opts.fetch(:rdbms)
        @lexicon = opts.fetch(:lexicon)
      end

      def schema
        SCHEMAS[data_model]
      end

      def data_model
        :gdm
      end

      def table_is_missing?(db)
        !(db.table_exists?(:concept) && db.table_exists?(:source_to_concept_map))
      end

      # For now, we'll return only the ids we're given as I'm not sure
      # we want to expand the search for concepts outside those specified
      # for OMOPv4.5+
      def related_concept_ids(db, *ids)
        ids
      end

      def concepts_ds(db, vocabulary_id, codes)
        standards = db[:concept]
          .where(vocabulary_id: vocabulary_id, concept_code: codes)
          .select(:vocabulary_id, :concept_code, Sequel[:concept_name].as(:concept_text))
          .from_self
        sources = db[:source_to_concept_map]
          .where(source_vocabulary_id: vocabulary_id, source_code: codes)
          .select(Sequel[:source_vocabulary_id].as(:vocabulary_id), Sequel[:source_code].as(:concept_code), Sequel[:source_code_description].as(:concept_text))
          .from_self
        standards.union(sources).order(:concept_code, :concept_text).from_self.select_group(:vocabulary_id, :concept_code).select_append(Sequel.function(:min, :concept_text).as(:concept_text)).from_self
      end

      def information_period_where_clause(arguments)
        return if arguments.empty?
        { plan_source_value: arguments }
      end
    end
  end
end

