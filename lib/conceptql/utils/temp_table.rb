require 'zlib'

module ConceptQL
  # TempTable coordinates the creation of any temporary tables a statement
  # might need.
  #
  # Currently, temp tables are used to share a set of results when a Recall
  # operator is present in a statement.
  #
  # It also provides an API to generate the SQL that Sequel would use to create
  # and populate the temp table
  class TempTable
    attr :operator
    def initialize(operator, db)
      @operator = operator
      fake_it!(db)
    end

    def build(db)
      @built ||= build_it(db)
    end

    def sql(db)
      # Sequel doesn't (currently) provide an API for getting the SQL for the
      # creation of tables, so we're calling one of the private methods
      sql = db[db.send(:create_table_as_sql, table_name, operator.evaluate(db), temp: true)].sql
      ["-- #{operator.label}", sql].join("\n")
    end

    def from(db)
      db[table_name]
    end

    private

    def table_name
      namify(operator.label)
    end

    def build_it(db)
      db.create_table!(table_name, as: operator.evaluate(db), temp: true)
      true
    end

    def namify(name)
      digest = Zlib.crc32 name
      ('_' + digest.to_s).to_sym
    end

    # Creates the temp table, but populates it with a single fake row of null
    # values.  Some operations, such as generating the SQL for a statement
    # Want the temp tables to exist, but we don't _really_ need the actual
    # results in the temp table since they might take a long time to calculate.
    def fake_it!(db)
      db.create_table!(table_name, temp: true, as: fake_row(db))
    end

    def fake_row(db)
      db
        .select(Sequel.cast(nil, Bignum).as(:person_id))
        .select_append(Sequel.cast(nil, Bignum).as(:criterion_id))
        .select_append(Sequel.cast(nil, String).as(:criterion_type))
        .select_append(Sequel.cast(nil, Date).as(:start_date))
        .select_append(Sequel.cast(nil, Date).as(:end_date))
        .select_append(Sequel.cast(nil, Bignum).as(:value_as_number))
        .select_append(Sequel.cast(nil, String).as(:value_as_string))
        .select_append(Sequel.cast(nil, Bignum).as(:value_as_concept_id))
        .select_append(Sequel.cast(nil, String).as(:units_source_value))
        .select_append(Sequel.cast(nil, String).as(:source_value))
    end
  end
end
