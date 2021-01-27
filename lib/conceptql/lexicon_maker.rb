module ConceptQL
  @lexicon_monitor = Monitor.new
  @lexicon_mutex = Mutex.new

  def self.lexicon_db
    @lexicon_mutex.synchronize do
      unless defined?(@lexicon_db)
        @lexicon_db = make_lexicon_db
      end
    end
    @lexicon_db
  end

  def self.with_lexicon(ddb = nil)
    #@lexicon_monitor.synchronize do
      lexi =  make_lexicon_db 
      lexi.synchronize do |_lexiconn|
      #lexicon_db.synchronize do |_lexiconn|
        if ddb
          ddb.synchronize do |_ddb_conn|
            yield Lexicon.new(lexi, ddb)
          end
        else
          yield Lexicon.new(lexi)
        end
      end
  ensure
    lexi.disconnect
    #end
  end

  def self.make_lexicon_db
    db_opts = {}

    if ENV["CONCEPTQL_LOG_LEXICON"]
      log_path = Pathname.new("log") + "conceptql_lexicon.log"
      log_path.dirname.mkpath
      db_opts[:logger] = Logger.new(log_path)
    end

    lexicon_db = if ENV["LEXICON_URL"]
                   Sequel.connect(ENV["LEXICON_URL"], db_opts)
                 else
                   Sequel.mock(host: :postgres)
                 end

    ConceptQL.db_extensions(lexicon_db)
    lexicon_db
  end
end
