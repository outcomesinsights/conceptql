module ConceptQL
  class LexiconStrategy
    attr_reader :db

    def initialize(db)
      @db = db
    end

    def db_is_mock?
      db.is_a?(Sequel::Mock::Database)
    end
  end
end