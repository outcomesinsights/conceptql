require_relative "lexicon_strategy"

module ConceptQL
  class LexiconOhdsi < LexiconStrategy
    FILE_PROVENANCE_TYPES_VOCAB = "JS_FILE_PROV_TYPE"
    CODE_PROVENANCE_TYPES_VOCAB = "JS_CODE_PROV_TYPE"

    class << self
      def db_has_all_vocabulary_tables?(db)
        %i(concept_ancestor concept concept_relationship vocabulary).all?{|t| db.table_exists?(t)}
      end
    end

    # Takes all concept_ids or a Sequel::Dataset
    # and finds all descendant_ids associated to the set of IDs passed in
    #
    # We also return back all concept_ids that were passed in.  That way,
    # if a concept_id isn't in our ancestors table, we still look for that
    # concept and don't secretly drop it
    def descendants_of(*concept_ids_or_ds)
      where_values = Array(concept_ids_or_ds).flatten.dup

      descendants = db[:concept_ancestor]
        .where(ancestor_concept_id: where_values)
        .select(:descendant_concept_id)

      unless where_values.empty?
        union_clause = db.values(where_values.map { |v| [v] })
        descendants = descendants.union(union_clause).distinct
      end

      descendants.select_map(:descendant_concept_id)
    end

    def codes_by_domain(codes, vocabulary_id)
      domains_and_codes = db[:concept]
        .where(concept_code: codes, vocabulary_id: translate_vocab_id(vocabulary_id))
        .to_hash_groups(:domain_id, :concept_code)

      domains_and_codes = ConceptQL::Utils.rekey(domains_and_codes)

      leftovers = codes - domains_and_codes.map(&:values).flatten
      domains_and_codes[:observation] ||= []
      domains_and_codes[:observation] += leftovers
      domains_and_codes
    end

    def known_codes(vocabulary_id, codes)
      return codes if db_is_mock?
      return codes if vocabulary_is_empty?(vocabulary_id)
      concepts(vocabulary_id, codes).select_map(:concept_code)
    end

    def concepts_to_codes(vocabulary_id, codes = [])
      concepts(vocabulary_id, codes).select_map([:concept_code, :concept_name])
    end

    def concepts(vocabulary_id, codes = [])
      ds = db[:concept].where(vocabulary_id: translate_vocab_id(vocabulary_id))
      ds = ds.where(Sequel.function(:lower, :concept_code) => Array(codes).map(&:downcase)) unless codes.blank?
      ds
    end

    def concept_ids(vocabulary_id, codes = [])
      concepts(vocabulary_id, codes).select_map(:concept_id)
    end

    def vocabulary_is_empty?(vocabulary_id)
      db[:concept].where(vocabulary_id: translate_vocab_id(vocabulary_id)).count.zero?
    end

    def translate_vocab_id(vocabulary_id)
      return vocabulary_id
    end

    def vocabularies_query
      db[:vocabulary]
        .select(Sequel[:vocabulary_id].as(:id),
                Sequel[:vocabulary_id].as(:omopv5_vocabulary_id),
                Sequel[:vocabulary_name].as(:vocabulary_short_name),
                Sequel[:vocabulary_name].as(:vocabulary_full_name),
                Sequel[nil].as(:domain),
                Sequel.expr(1).as(:from_lexicon))
        .from_self
    end

    def vocabularies
      vocabularies_query.all
    end

    def file_provenance_types_vocab
      FILE_PROVENANCE_TYPES_VOCAB
    end

    def code_provenance_types_vocab
      CODE_PROVENANCE_TYPES_VOCAB
    end
  end
end