module ConceptQL
  module DataModel
    class Generic
      SCHEMAS = Dir.glob((ConceptQL.schemas + "*.yml").tap{|o|p o}).tap {|o| p o}.each_with_object({}) do |schema_file, schemas|
        schemas[File.basename(schema_file, ".*").to_sym] = Psych.load_file(schema_file)
      end

      attr :operator, :nodifier
      def initialize(operator, nodifier)
        @operator = operator
        @nodifier = nodifier
      end

      def query_modifier_for(column)
        {
          place_of_service_concept_id: ConceptQL::QueryModifiers::Generic::PosQueryModifier,
          drug_name: ConceptQL::QueryModifiers::Generic::DrugQueryModifier
        }[column]
      end

      def criterion_id
        :criterion_id
      end

      def table_id(table = nil)
        return :criterion_id if table.nil?
        table = :person if table == :death
      end

      def person_table
        :person
      end

      def make_table_id(table)
        (table.to_s + '_id').to_sym
      end

      def person_id
        :person_id
      end

      def person_id_column(query)
        :person_id
      end

      def schema
        SCHEMAS[data_model]
      end

      def data_model
        :omopv4_plus
      end

      def query_columns(query)
        unless cols = query.opts[:force_columns]
          cols = operator.query_cols
        end

        if ENV['CONCEPTQL_CHECK_COLUMNS']
          if cols.sort != query.columns.sort
            raise "columns don't match:\nclass: #{self.class}\nexpected: #{cols}\nactual: #{query.columns}\nvalues: #{values}\nSQL: #{query.sql}"
          end
        end

        cols
      end

      def place_of_service_concept_id(query, domain)
        return :place_of_service_concept_id if query_columns(query).include?(:place_of_service_concept_id)
        place_of_service_concept_id_column(query, domain)
      end

      def determine_table(table_method)
        return nil unless operator.respond_to?(table_method)
        table = operator.send(table_method)
        return table if schema.keys.include?(table)
      end

      def assign_column_to_table
        schema.each_with_object({}) do |(table, column_info), cols|
          column = yield table, column_info.keys.map(&:to_s)
          cols[table] = column ? column.to_sym : nil
        end
      end

      def start_date_columns
        @start_date_columns ||= assign_column_to_table do |table, columns|
          column = columns.select { |k| k =~ /start_date$/ }.first
          column ||= columns.select { |k| k =~ /date$/ }.first
        end
      end

      def end_date_columns
        @end_date_columns ||= assign_column_to_table do |table, columns|
          column = columns.select { |k| k =~ /end_date$/ }.first
          column ||= columns.select { |k| k =~ /date$/ }.first
        end
      end

      def start_date_column(query, domain)
        if oi_cdm?
          start_date_columns[domain]
        else
          start_date_columns.merge(person: person_date_of_birth(query))[domain]
        end
      end

      def end_date_column(query, domain)
        if oi_cdm?
          end_date_columns[domain]
        else
          end_date_columns.merge(person: person_date_of_birth(query))[domain]
        end
      end

      def source_value_columns
        @source_value_columns ||= assign_column_to_table do |table, columns|
          reggy = /#{table.to_s.split("_").first}_source_value$/
          column = columns.select { |k| k =~ reggy }.first
          column ||= columns.select { |k| k =~ /source_value$/ }.first
        end
      end

      def table_vocabulary_ids
        @table_vocabulary_ids = assign_column_to_table do |table, columns|
          reggy = /#{table.to_s.split("_").first}_source_vocabulary_id/
          column = columns.select { |k| k =~ reggy }.first
          column ||= columns.select { |k| k =~ /_source_vocabulary_id/ }.first
        end
      end

      def id_columns
        @id_columns ||= assign_column_to_table do |table, columns|
          reggy = /#{table.to_s}_id/
          columns.select { |k| k =~ reggy }.first
        end
      end

      def id_column(table)
        id_columns[table]
      end

      def period_table
        :observation_period
      end

      def source_value_column(query, table)
        source_value_columns[table]
      end

      def provenance_type_column(query, domain)
        {
          condition_occurrence: :condition_type_concept_id,
          death: :death_type_concept_id,
          drug_exposure: :drug_type_concept_id,
          observation: :observation_type_concept_id,
          procedure_occurrence: :procedure_type_concept_id
        }[domain]
      end

      def provider_id_column(query, domain)
        {
          condition_occurrence: :associated_provider_id,
          death: :death_type_concept_id,
          drug_exposure: :prescribing_provider_id,
          observation: :associated_provider_id,
          person: :provider_id,
          procedure_occurrence: :associated_provider_id,
          provider: :provider_id
        }[domain]
      end

      def place_of_service_concept_id_column(query, domain)
        return nil if domain.nil?
        return Sequel.cast(:place_of_service_concept_id, :Bigint) if table_cols(domain).include?(pos_table_fk)
        return nil
      end

      def pos_table_fk
        :visit_occurrence_id
      end

      def person_date_of_birth(query)
        assemble_date(query, :year_of_birth, :month_of_birth, :day_of_birth)
      end

      def assemble_date(query, *symbols)
        strings = symbols.map do |symbol|
          sub = '2000'
          col = Sequel.cast_string(symbol)
          if symbol != :year_of_birth
            sub = '01'
            col = Sequel.function(:lpad, col, 2, '0')
          end
          Sequel.function(:coalesce, col, Sequel.expr(sub))
        end

        strings_with_dashes = strings.zip(['-'] * (symbols.length - 1)).flatten.compact
        concatted_strings = Sequel.join(strings_with_dashes)

        date = concatted_strings
        if query.db.database_type == :impala
          date = Sequel.cast(Sequel.function(:concat_ws, '-', *strings), DateTime)
        end
        operator.cast_date(query.db, date)
      end

      def date_columns(query, table = nil)
        return [:start_date, :end_date] if (query_columns(query).include?(:start_date) && query_columns(query).include?(:end_date))
        return [:start_date, :end_date] unless table

        date_klass = Date
        if query.db.database_type == :impala
          date_klass = DateTime
        end

        sd = start_date_column(query, table)
        sd = Sequel.cast(Sequel.expr(sd), date_klass).as(:start_date) unless sd == :start_date
        ed = end_date_column(query, table)
        ed = Sequel.cast(Sequel.function(:coalesce, Sequel.expr(ed), start_date_column(query, table)), date_klass).as(:end_date) unless ed == :end_date
        [sd, ed]
      end

      def table_to_sym(table)
        case table
        when Symbol
          table = Sequel.split_symbol(table)[1].to_sym
        end
        table
      end

      def table_cols(table)
        table = table_to_sym(table)
        cols = schema.fetch(table).keys
        cols
      end

      def table_columns(*tables)
        tables.map{|t| table_cols(t)}.flatten
      end

      def table_source_value(table)
        source_value_columns.fetch(table_to_sym(table))
      end

      def table_vocabulary_id(table)
        table_vocabulary_ids[table_to_sym(table)]
      end

      def table_is_missing?(db)
        !(db.table_exists?(:concept) && db.table_exists?(:source_to_concept_map))
      end
    end
  end
end
