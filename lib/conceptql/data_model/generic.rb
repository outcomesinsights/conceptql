module ConceptQL
  module DataModel
    class Generic
      SCHEMAS = Dir.glob((ConceptQL.schemas + "*.yml").tap{|o|p o}).each_with_object({}) do |schema_file, schemas|
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
          drug_name: ConceptQL::QueryModifiers::Generic::DrugQueryModifier,
          provider_id: ConceptQL::QueryModifiers::Generic::ProviderQueryModifier
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

      def make_fk_id(table)
        make_table_id(table)
      end

      def convert_table(table)
        table
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

      def pk_by_domain(domain)
        "#{domain}_id"
      end

      def fk_by_domain(domain)
        "#{domain}_id"
      end

      def query_columns
        @query_columns ||= Hash[operator.scope.query_columns.zip(operator.scope.query_columns)]
      end

      def columns(opts = {})
        col_keys = query_columns.keys
        col_keys -= opts[:except] || []
        col_keys &= opts[:only] if opts[:only]

        table = get_table(opts)

        cols_hash = if table.nil?
                      query_columns
                    else
                      columns_in_table(table, opts).merge(modifier_columns(table)).merge(nullified_columns(table))
                    end
        cols_hash.merge!(replace(opts[:replace]))
        cols_hash.values_at(*col_keys)
      end

      def modifier_columns(table)
        return {} if table.nil?
        remainder = query_columns.keys - columns_in_table(table).keys
        Hash[remainder.zip(remainder)]
      end

      def nullified_columns(table)
        return {} if table.nil?
        remainder = query_columns.keys - columns_in_table(table).keys - applicable_query_modifiers(table).flat_map(&:provided_columns)
        Hash[remainder.map { |r| [r, process(r, nil)] }]
      end

      def selectify(query, opts ={})
        modify_query(query, get_table(opts)).select(*columns(opts)).from_self
      end

      def get_table(opts)
        opts[:table] || table_by_domain(opts[:domain])
      end

      def modify_query(query, table)
        return query if table.nil?

        applicable_query_modifiers(table).each do |klass|
          query = klass.new(query, operator, table, self).modified_query
        end

        query
      end

      def applicable_query_modifiers(table)
        query_modifiers.values_at(*query_columns.keys).compact.select { |klass| klass.has_required_columns?(table_cols(table)) }
      end

      def query_modifiers
        {
          place_of_service_concept_id: query_modifier_for(:place_of_service_concept_id),
          provider_id: query_modifier_for(:provider_id),
          drug_name: query_modifier_for(:drug_name)
        }
      end

      def columns_in_table(table, opts = {})
        start_date, end_date = *date_columns(nil, table)
        {
          person_id: person_id_column(table),
          criterion_id: Sequel.identifier(make_table_id(table)).as(:criterion_id),
          criterion_table: Sequel.cast_string(table.to_s).as(:criterion_table),
          criterion_domain: Sequel.cast_string((opts[:criterion_domain] || table).to_s).as(:criterion_domain),
          start_date: start_date,
          end_date: end_date,
          source_value: Sequel.cast_string(source_value_column(table)).as(:source_value),
        }
      end

      def replace(replace_hash)
        return {} unless replace_hash
        replace_hash.each_with_object({}) do |(column, value), h|
          h[column] = process(column, value)
        end
      end

      def process(column, value = nil)
        type = Scope::COLUMN_TYPES.fetch(column)
        new_column = case type
        when String, :String
          Sequel.cast_string(value)
        when Date, :Date
          Sequel.cast(value, type)
        when Float, :Bigint, :Float
          Sequel.cast_numeric(value, type)
        else
          raise "Unexpected type: '#{type.inspect}' for column: '#{column}'"
        end
        new_column.as(column)
      end

      def cast_date(date)
        Sequel.cast(date, Date)
      end

=begin
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
=end

      def place_of_service_concept_id(query, domain)
        #return :place_of_service_concept_id if query_columns(query).include?(:place_of_service_concept_id)
        place_of_service_concept_id_column(query, domain)
      end

      def determine_table(table_method)
        return nil unless operator.respond_to?(table_method)
        table = table_by_domain(operator.send(table_method))
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
        start_date_columns.merge(person: person_date_of_birth(query))[domain]
      end

      def end_date_column(query, domain)
        end_date_columns.merge(person: person_date_of_birth(query))[domain]
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

      def type_concept_id_columns
        @type_concept_id_columns ||= assign_column_to_table do |table, columns|
          columns.select { |c| c =~ /_type_concept_id$/ }.first
        end
      end

      def type_concept_id_column(domain)
        type_concept_id_columns[table_by_domain(domain)]
      end

      def table_by_domain(domain)
        domain
      end

      def condition_table
        :condition_occurrence
      end

      def period_table
        :observation_period
      end

      def source_value_column(table)
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
        #return [:start_date, :end_date] if (query_columns(query).include?(:start_date) && query_columns(query).include?(:end_date))
        #return [:start_date, :end_date] unless table

        date_klass = Date
        #if query.db.database_type == :impala
        #  date_klass = DateTime
        #end

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
