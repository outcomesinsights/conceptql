require 'forwardable'

module ConceptQL
  class StatementResults
    class << self
      def create(test_name, cdb, statement, remove_window_id = false)
        test_type = test_name.split('/').last.split('_').first

        case test_type
        when 'crit'
          CriteriaIdsResults.new(cdb, statement, remove_window_id)
        when 'anno'
          AnnotationResults.new(cdb, statement, remove_window_id)
        when 'count'
          CriteriaCountsResults.new(cdb, statement, remove_window_id)
        when 'optcc'
          OptimizedCriteriaCountsResults.new(cdb, statement, remove_window_id)
        when 'scanno'
          ScopeAnnotationResults.new(cdb, statement, remove_window_id)
        when 'domains'
          DomainsResults.new(cdb, statement, remove_window_id)
        when 'num'
          NumericValuesResults.new(cdb, statement, remove_window_id)
        when 'codes'
          CodeCheckResults.new(cdb, statement, remove_window_id)
        when 'results'
          ResultsResults.new(cdb, statement, remove_window_id)
        else
          raise "Invalid operation test prefix: #{test_type}"
        end
      end
    end

    extend Forwardable
    attr_reader :cdb, :statement, :remove_window_id

    def_delegators :cdb, :query

    def initialize(cdb, statement, remove_window_id)
      @cdb = cdb
      @statement = statement
      @remove_window_id = remove_window_id
    end

    def cql_query
      query(statement)
    end

    def dataset
      stmt = query(statement) unless statement.is_a?(ConceptQL::Query)
      puts stmt.sql if PRINT_CONCEPTQL
      stmt.query
    end

    def hash_groups(key, value)
      dataset.from_self.distinct.order(key, *value).to_hash_groups(key, value)
    rescue StandardError
      puts $ERROR_INFO.sql if $ERROR_INFO.respond_to?(:sql)
      raise
    end

    def fetch
      prep
    end

    def save(path, to_save = nil)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, JSON.pretty_generate(to_save || fetch))
    end

    def pure_sql?
      false
    end
  end

  class AnnotationResults < StatementResults
    def fetch
      cql_query.annotate
    end
  end

  class ScopeAnnotationResults < StatementResults
    def fetch
      cql_query.scope_annotate
    end
  end

  class DomainsResults < StatementResults
    def fetch
      cql_query.domains
    end
  end

  class CriteriaIdsResults < StatementResults
    def fetch
      hash_groups(:criterion_domain, :criterion_id)
    end
  end

  class CodeCheckResults < StatementResults
    def fetch
      cql_query.code_list.map(&:to_s)
    end
  end

  class NumericValuesResults < StatementResults
    def fetch
      hash_groups(:criterion_domain, :value_as_number)
    end
  end

  class CriteriaCountsResults < StatementResults
    def prep
      cq = cql_query
      puts cq.sql if PRINT_CONCEPTQL
      cq.query.from_self.group_and_count(:criterion_domain).order(:criterion_domain)
    end

    def fetch
      prep.to_hash(:criterion_domain, :count)
    end
  end

  class OptimizedCriteriaCountsResults < CriteriaCountsResults
    def cql_query
      super.optimize
    end
  end

  class ResultsResults < StatementResults
    def prep
      ds = dataset.from_self

      if cdb.data_model.data_model == :gdm_wide
        cols = ds.columns
        if cols.include?(:criterion_table)
          ds = ds.select(*(cols - [:criterion_table]))
                 .select_append(
                   Sequel.case({ 'observations' => 'clinical_codes' }, :criterion_table,
                               :criterion_table).as(:criterion_table)
                 )
                 .from_self
                 .select(*cols) # Preserve the original column order
                 .from_self
        end
        if cols.include?(:uuid)
          ds = ds.select(*(cols - [:uuid]))
                 .select_append(
                   Sequel.function(:regexp_replace, :uuid, 'observations', 'clinical_codes').as(:uuid)
                 )
                 .from_self
                 .select(*cols) # Preserve the original column order
                 .from_self
        end
      end

      order_columns = %i[person_id criterion_table criterion_domain start_date criterion_id]
      order_columns << :uuid if ds.columns.include?(:uuid)
      order_columns << :window_id if ds.columns.include?(:window_id)
      ds = ds.order(*order_columns)
      ds = ds.select_remove(:window_id) if remove_window_id
      ds
    end

    def fetch
      prep.all
    end

    def pure_sql?
      true
    end
  end

  class StatementFileTest
    class << self
      def all(cdb, file_regexps = nil)
        Pathname.glob('./test/statements/**/*').reject do |f|
          f.directory? || (file_regexps.present? && file_regexps.none? { |r| f.to_s =~ r })
        end.map { |f| ConceptQL::StatementFileTest.new(cdb, f) }
      end
    end

    extend Forwardable

    attr_reader :cdb, :statement_file

    def_delegators :cdb, :query

    def initialize(cdb, f)
      @cdb = cdb
      @statement_file = f
    end

    def statement
      @statement ||= JSON.parse(File.read(statement_file))
    end

    def each_test(&block)
      load_check(&block)
    end

    def test_name
      @test_name ||= [statement_file.dirname.basename, statement_file.basename]
                     .map(&:to_s)
                     .join('/')
    end

    def get_expected_results(results)
      path = "test/results/#{cdb.base_data_model}/#{test_name}"

      results.save(path) if ENV['CONCEPTQL_OVERWRITE_TEST_RESULTS']

      begin
        File.read(path)
      rescue Errno::ENOENT
        results.save(path, { fail: true })
        '{ "fail": true }'
      end
    end

    def yield_a_test(results, expected, expect_message = nil, &block)
      message_parts = [test_name]
      message_parts << expect_message if expect_message
      message_parts << PP.pp(statement, ''.dup, 10) if PRINT_CONCEPTQL

      block.call(results, expected, test_name, message_parts.join(' '))
      results
    end

    def result_from(statement, remove_window_id)
      StatementResults.create(test_name, cdb, statement, remove_window_id)
    end

    def load_check(&block)
      basic_results = result_from(statement, false)
      expected_results = get_expected_results(basic_results)

      # Check without scope windows
      yield_a_test(basic_results, expected_results, &block)

      # Check with scope windows, unless the test is already a scope window test
      unless statement.first == 'window'
        sw_statement = ['window', statement,
                        { 'window_table' => ['date_range', { 'start' => '1900-01-01', 'end' => '2100-12-31' }] }]
        yield_a_test(result_from(sw_statement, true), expected_results, ' (with window table)', &block)

        sw_statement = ['window', statement, { 'start_date' => '1900-01-01', 'end_date' => '2100-12-31' }]
        yield_a_test(result_from(sw_statement, true), expected_results, ' (with window table)', &block)
      end

      unless SKIP_SQL_GENERATION_TEST
        begin
          query(statement).sql(:create_tables)
          query(['window', statement,
                 { 'window_table' => ['date_range', { 'start' => '1900-01-01', 'end' => '2100-12-31' }] }]).sql(:create_tables)
          query(['window', statement,
                 { 'start_date' => '1900-01-01', 'end_date' => '2100-12-31' }]).sql(:create_tables)
        rescue ConceptQL::Query::QueryError
          # Suppress this new issue
        end
      end

      if PERFORMANCE_TEST_TIMES.positive?
        times = PERFORMANCE_TEST_TIMES.times.map do
          before = clock_time
          yield(statement, false)
          clock_time - before
        end
        avg_time = times.sum / times.length

        path = "test/performance/#{CDB.base_data_model}/#{test_name.sub(/\.json\z/, '.csv')}"
        sha1 = `git rev-parse HEAD`.chomp
        adapter = "#{DB.adapter_scheme}/#{DB.database_type}"

        FileUtils.mkdir_p(File.dirname(path))
        File.open(path, 'ab') do |file|
          file.puts([sha1, adapter, DB.opts[:database], Time.now, avg_time].join(','))
        end
      end
    rescue StandardError
      puts $ERROR_INFO.sql if $ERROR_INFO.respond_to?(:sql)
      raise
    end

    def pure_sql?
      true
    end
  end
end
