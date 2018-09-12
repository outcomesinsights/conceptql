module ConceptQL
  class Lexicon
    attr_reader :db

    def initialize(db)
      @db = db
    end

    def codes_by_domain(codes, vocabulary_id)
      domains_and_codes = db[:concepts]
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
      db[:concepts]
        .where(vocabulary_id: translate_vocab_id(vocabulary_id), concept_code: codes)
    end

    def translate_vocab_id(vocabulary_id)
      Array(vocabulary_id).map do |vocab_id|
        vocab_translator[vocab_id.to_s]
      end
    end

    def vocab_translator
      @vocab_translator ||= db[:vocabularies]
        .select(Sequel.cast_string(:omopv4_id).as(:original_id), Sequel.cast_string(:omopv5_id).as(:new_id))
        .union(db[:vocabularies].select(Sequel.cast_string(:omopv5_id).as(:original_id), Sequel.cast_string(:omopv5_id).as(:new_id)))
        .to_hash(:original_id, :new_id)
    end

    def vocabularies
      db[:vocabularies]
        .select(Sequel[:omopv5_id].as(:id),
                Sequel[:omopv5_id].as(:omopv5_vocabulary_id),
                Sequel[:omopv4_id].as(:omopv4_vocabulary_id),
                Sequel[:vocabulary_name].as(:vocabulary_short_name),
                Sequel[:vocabulary_name].as(:vocabulary_full_name),
                Sequel.expr(1).as(:from_lexicon))
        .all
    end
  end
end
