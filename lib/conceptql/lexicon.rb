module ConceptQL
  class Lexicon
    attr_reader :lexicon_db, :dataset_db, :tables

    def initialize(lexicon_db, dataset_db = nil)
      @lexicon_db = lexicon_db
      @dataset_db = dataset_db
      @tables = {}
    end

    def codes_by_domain(codes, vocabulary_id)
      domains_and_codes = concepts_table
        .where(concept_code: codes, vocabulary_id: translate_vocab_id(vocabulary_id))
        .to_hash_groups(:domain_id, :concept_code)

      domains_and_codes = ConceptQL::Utils.rekey(domains_and_codes)

      leftovers = codes - domains_and_codes.map(&:values).flatten
      domains_and_codes[:observation] ||= []
      domains_and_codes[:observation] += leftovers
      domains_and_codes
    end

    def known_codes(vocabulary_id, codes)
      concepts(vocabulary_id, codes).select_map(:concept_code)
    end

    def concepts(vocabulary_id, codes)
      concepts_table
        .where(vocabulary_id: translate_vocab_id(vocabulary_id), concept_code: codes)
    end

    def translate_vocab_id(vocabulary_id)
      Array(vocabulary_id).map do |vocab_id|
        vocab_translator[vocab_id.to_s]
      end
    end

    def vocab_translator
      @vocab_translator ||= vocabularies_table
        .select(Sequel.cast_string(:omopv4_id).as(:original_id), Sequel.cast_string(:omopv5_id).as(:new_id))
        .union(vocabularies_table.select(Sequel.cast_string(:omopv5_id).as(:original_id), Sequel.cast_string(:omopv5_id).as(:new_id)))
        .to_hash(:original_id, :new_id)
    end

    def vocabularies
      vocabularies_table
        .select(Sequel[:omopv5_id].as(:id),
                Sequel[:omopv5_id].as(:omopv5_vocabulary_id),
                Sequel[:omopv4_id].as(:omopv4_vocabulary_id),
                Sequel[:vocabulary_name].as(:vocabulary_short_name),
                Sequel[:vocabulary_name].as(:vocabulary_full_name),
                Sequel.expr(1).as(:from_lexicon))
        .all
    end

    %i(ancestors concepts mappings vocabularies).each do |meth|
      define_method("#{meth}_table") do
        tables[meth] ||= send("get_#{meth}_table")
      end

      define_method("get_#{meth}_table") do
        if dataset_db && dataset_db.table_exists?(meth)
          dataset_db[meth]
        else
          lexicon_db[meth]
        end
      end
    end
  end
end
