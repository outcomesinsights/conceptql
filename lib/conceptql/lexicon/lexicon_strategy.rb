module ConceptQL
  class LexiconStrategy
    attr_reader :db, :db_lock

    def initialize(db, db_lock)
      @db = db
      @db_lock = db_lock
    end

    def db_is_mock?
      db.is_a?(Sequel::Mock::Database)
    end

    def with_db
      db_lock.synchronize do
        _db = db
        _db.synchronize { yield _db }
      end
    end
  end
end