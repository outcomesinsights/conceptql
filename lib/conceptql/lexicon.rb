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

      leftovers = arguments - domains_and_codes.map(&:values).flatten
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
      vocab_translator[vocabulary_id.to_s]
    end

    def vocab_translator
      @vocab_translator ||= db[:vocabularies]
        .select(Sequel.cast_string(:omopv4_id).as(:omopv4_id), :omopv5_id)
        .union(db[:vocabularies].select(:omopv5_id, :omopv5_id))
        .to_hash
    end
  end
end
