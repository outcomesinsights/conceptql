module ConceptQL
  class Lexicon
    attr_reader :lexicon_db, :dataset_db, :tables, :db_lock
    @@db_lock = Mutex.new

    def initialize(lexicon_db, dataset_db = nil)
      @lexicon_db = lexicon_db
      @dataset_db = dataset_db
      @db_lock = Mutex.new
      @tables = {}
    end

    # Takes all concept_ids or a Sequel::Dataset
    # and finds all descendant_ids associated to the set of IDs passed in
    #
    # We also return back all concept_ids that were passed in.  That way,
    # if a concept_id isn't in our ancestors table, we still look for that
    # concept and don't secretly drop it
    def descendants_of(*concept_ids_or_ds)
      where_values = concept_ids_or_ds.dup
      union_clause = []

      if where_values.last.is_a?(Sequel::Dataset)
        union_clause = where_values = where_values.pop
      else
        union_clause = lexicon_db.values(where_values.map { |v| [v] })
      end

      descendants = ancestors_table
        .where(ancestor_id: where_values)
        .select(:descendant_id)
      descendants.union(union_clause).distinct
    end

    def codes_by_domain(codes, vocabulary_id)
      domains_and_codes = lexicon_db[:concepts]
        .where(concept_code: codes, vocabulary_id: translate_vocab_id(vocabulary_id))
        .to_hash_groups(:domain_id, :concept_code)

      domains_and_codes = ConceptQL::Utils.rekey(domains_and_codes)

      leftovers = codes - domains_and_codes.map(&:values).flatten
      domains_and_codes[:observation] ||= []
      domains_and_codes[:observation] += leftovers
      domains_and_codes
    end

    def known_codes(vocabulary_id, codes)
      return codes if lexicon_db_is_mock?
      return codes if vocabulary_is_empty?(vocabulary_id)
      concepts(vocabulary_id, codes).select_map(:concept_code)
    end

    def concepts(vocabulary_id, codes)
      lexicon_db[:concepts]
        .where(vocabulary_id: translate_vocab_id(vocabulary_id), Sequel.function(:lower, :concept_code) => Array(codes).map(&:downcase))
    end

    def vocabulary_is_empty?(vocabulary_id)
      lexicon_db[:concepts].where(vocabulary_id: translate_vocab_id(vocabulary_id)).count.zero?
    end

    def translate_vocab_id(vocabulary_id)
      return vocabulary_id
    end

    def vocab_translator
      @vocab_translator ||= lexicon_db[:vocabularies]
        .select(Sequel.cast_string(:omopv4_id).as(:original_id), Sequel.cast_string(:omopv5_id).as(:new_id))
        .union(lexicon_db[:vocabularies].select(Sequel.cast_string(:omopv5_id).as(:original_id), Sequel.cast_string(:omopv5_id).as(:new_id)))
        .to_hash(:original_id, :new_id)
    end

    def vocabularies
      lexicon_db[:vocabularies]
        .select(Sequel[:id].as(:id),
                Sequel[:id].as(:omopv5_vocabulary_id),
                Sequel[:vocabulary_name].as(:vocabulary_short_name),
                Sequel[:vocabulary_name].as(:vocabulary_full_name),
                Sequel[:domain],
                Sequel.expr(1).as(:from_lexicon))
        .all
    end

    def lexicon_db_is_mock?
      lexicon_db.is_a?(Sequel::Mock::Database)
    end

    def db
      if dataset_db && db_has_all_vocabulary_tables?(dataset_db) && !dataset_db.is_a?(Sequel::Mock::Database)
        dataset_db
      else
        lexicon_db
      end
    end

    def with_db
      @@db_lock.synchronize do
        _db = db
        _db.synchronize { yield _db }
      end
    end

    def db_has_all_vocabulary_tables?(db_)
      %i(ancestors concepts mappings vocabularies).all?{|t| db_.table_exists?(t)}
    end

    %i(ancestors concepts mappings vocabularies).each do |meth|
      define_method("#{meth}_table") do
        tables[meth.to_sym] ||= send("get_#{meth}_table")
      end

      define_method("get_#{meth}_table") do
        if dataset_db && dataset_db.table_exists?(meth) && !dataset_db.is_a?(Sequel::Mock::Database)
          dataset_db[meth.to_sym]
        else
          lexicon_db[meth.to_sym]
        end
      end
    end

  end
end
