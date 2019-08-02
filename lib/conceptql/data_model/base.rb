require "psych"

module ConceptQL
  module DataModel
    class Base
      SCHEMAS = Dir.glob(ConceptQL.schemas_dir + "*.yml").each_with_object({}) do |schema_file, schemas|
        schemas[File.basename(schema_file, ".*").to_sym] = Psych.load_file(schema_file)
      end

      attr :operator, :nodifier
      def initialize(operator, nodifier)
        @operator = operator
        @nodifier = nodifier
      end

      def rdbms
        @rdbms ||= ConceptQL::Rdbms.generate(nodifier.database_type)
      end

      def query_modifier_for(column)
        {
          visit_source_concept_id: ConceptQL::QueryModifiers::Omopv4Plus::PoSQueryModifier,
          provider_id: ConceptQL::QueryModifiers::Omopv4Plus::ProviderQueryModifier,
          drug_name: ConceptQL::QueryModifiers::Omopv4Plus::DrugQueryModifier,
          admission_date: ConceptQL::QueryModifiers::Omopv4Plus::AdmissionDateQueryModifier,
          provenance_type: ConceptQL::QueryModifiers::Omopv4Plus::ProvenanceQueryModifier,
        }[column]
      end

      def criterion_id
        :criterion_id
      end

      def table_id(table = nil)
        return :person_id if table.to_sym == :death
        return :criterion_id if table.nil?
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

      def person_id(table)
        case table.to_sym
        when :procedure_cost, :drug_cost
          nil
        else
          :person_id
        end
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
        case domain.to_sym
        when :death
          :person_id
        when :procedure_cost
          :procedure_occurrence_id
        when :drug_cost
          :drug_exposure_id
        else
          "#{domain}_id".to_sym
        end
      end

      def fk_by_domain(domain)
        "#{domain}_id".to_sym
      end

      def query_columns
        @query_columns ||= Hash[operator.scope.query_columns.zip(operator.scope.query_columns)]
      end

      def columns(opts = {})
        table = get_table(opts)

        cols_hash = if table.nil? && opts[:query_columns].nil?
                      query_columns
                    else
                      columns_in_table(table, opts).merge(modifier_columns(table, opts)).merge(nullified_columns(table, opts))
                    end.dup

        except_keys = opts[:except] || []
        if cols_hash.has_key?(:uuid)
          if opts[:uuid]
            except_keys << :uuid
          elsif table
            cols_hash.merge!(uuid: Sequel.cast(nil, String).as(:uuid))
          end
        end
        col_keys = cols_hash.keys
        col_keys -= except_keys
        col_keys &= opts[:only] if opts[:only]

        if qualifier = opts[:qualifier]
          cols_hash = Hash[cols_hash.map { |k, c| [k, Sequel.qualify(qualifier, c)] }]
        end

        cols_hash.merge!(replace(opts[:replace]))
        cols_hash.values_at(*col_keys)
      end

      def modifier_columns(table, opts = {})
        return {} if table.nil? && opts[:query_columns].nil?
        remainder = query_columns.keys - (opts[:query_columns] ? opts[:query_columns].keys : columns_in_table(table).keys)
        Hash[remainder.zip(remainder)]
      end

      def nullified_columns(table, opts = {})
        return {} if table.nil? && opts[:query_columns].nil?
        remainder = query_columns.keys
        if opts[:query_columns]
          remainder -= opts[:query_columns].keys
        else
          remainder -= table_cols(table)
          remainder -= columns_in_table(table).keys
          remainder -= applicable_query_modifiers(table).flat_map(&:provided_columns)
        end

        Hash[remainder.map { |r| [r, rdbms.process(r, nil)] }]
      end

      def selectify(query, opts = {})
        ds = modify_query(query, get_table(opts)).select(*columns(opts))
        if opts[:uuid]
          ds = ds.from_self.select_append(rdbms.uuid.as(:uuid))
        end
        ds.from_self
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
          visit_source_concept_id: query_modifier_for(:visit_source_concept_id),
          provider_id: query_modifier_for(:provider_id),
          drug_name: query_modifier_for(:drug_name),
          file_provenance_type: query_modifier_for(:provenance_type),
          admission_date: query_modifier_for(:admission_date),
          value_as_number:  query_modifier_for(:value_as_number)
        }
      end

      def columns_in_table(table, opts = {})
        return opts[:query_columns] unless opts[:query_columns].nil?
        start_date, end_date = *date_columns(nil, table)
        {
          person_id: Sequel.expr(person_id(table)).as(:person_id),
          criterion_id: Sequel.identifier(pk_by_domain(table)).as(:criterion_id),
          criterion_table: Sequel.cast_string(table.to_s).as(:criterion_table),
          criterion_domain: Sequel.cast_string((opts[:criterion_domain] || table_to_domain(table) || table).to_s).as(:criterion_domain),
          start_date: start_date,
          end_date: end_date,
          source_value: Sequel.cast_string(source_value_column(table)).as(:source_value),
          source_vocabulary_id: Sequel.cast_string(source_vocabulary_id(table)).as(:source_vocabulary_id)
        }
      end

      def table_to_domain(table)
        table
      end

      def replace(replace_hash)
        return {} unless replace_hash
        replace_hash.each_with_object({}) do |(column, value), h|
          h[column] = rdbms.process(column, value)
        end
      end

      def place_of_service_concept_id(query, domain)
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

      def source_vocabulary_ids
        @source_vocabulary_ids = assign_column_to_table do |table, columns|
          next if %w(person death).any? { |tn| table.to_s =~ /#{tn}/ }
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

      def code_provenance_type_column(query, domain)
        {
          condition_occurrence: :condition_type_concept_id,
          death: :death_type_concept_id,
          drug_exposure: :drug_type_concept_id,
          observation: :observation_type_concept_id,
          procedure_occurrence: :procedure_type_concept_id
        }[domain]
      end

      def file_provenance_type_column(query, domain)
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
        return Sequel.cast(:visit_source_concept_id, :Bigint) if table_cols(domain).include?(pos_table_fk)
        return nil
      end

      def pos_table_fk
        :visit_occurrence_id
      end

      def person_date_of_birth(query)
        rdbms.cast_date(ConceptQL::Utils.assemble_date(:year_of_birth, :month_of_birth, :day_of_birth, database_type: nodifier.database_type))
      end

      def date_columns(query, table = nil)
        sd = start_date_column(query, table)
        sd = rdbms.cast_date(Sequel.expr(sd)).as(:start_date) unless sd == :start_date
        ed = end_date_column(query, table)
        ed = rdbms.cast_date(Sequel.function(:coalesce, Sequel.expr(ed), start_date_column(query, table))).as(:end_date) unless ed == :end_date
        [sd, ed]
      end

      def table_to_sym(table)
        case table
        when Symbol
          table = Sequel.split_symbol(table)[1].to_sym if Sequel.split_symbols?
        when Sequel::SQL::AliasedExpression
          table = table.expression
        when Sequel::SQL::QualifiedIdentifier
          table = table.column
        when Sequel::SQL::Identifier
          table = table.value
        end
        table.to_sym
      end

      def table_cols(table)
        table = table_to_sym(table)
        cols = schema.fetch(table).keys
        cols
      end

      def table_columns(*tables)
        tables.map { |t| table_cols(t) }.flatten.tap { |o| p o; p tables}
      end

      def table_source_value(table)
        source_value_columns.fetch(table_to_sym(table))
      end

      def source_vocabulary_id(table)
        source_vocabulary_ids[table_to_sym(table)]
      end

      def table_is_missing?(db)
        !(db.table_exists?(:concept) && db.table_exists?(:source_to_concept_map))
      end

      # For now, we'll return only the ids we're given as I'm not sure
      # we want to expand the search for concepts outside those specified
      # for OMOPv4.5+
      def related_concept_ids(db, *ids)
        ids
      end

      def concept_id(table)
        table_cols(table).find do |col|
          col = col.to_s
          next unless col =~ /concept_id/

          table_parts = table.to_s.chomp("s").to_s.split("_")

          possible_names = ["concept_id"]

          until table_parts.empty?
            possible_names.unshift([table_parts.join("_"), possible_names.last].join("_"))
            table_parts.pop
          end

          possible_names.any? do |name|
            col == name
          end
        end
      end

      def concepts_ds(db, vocabulary_id, codes)
        standards = db[:concept]
          .where(vocabulary_id: vocabulary_id, concept_code: codes)
          .select(:vocabulary_id, :concept_code, Sequel[:concept_name].as(:concept_text))
          .from_self
        sources = db[:source_to_concept_map]
          .where(source_vocabulary_id: vocabulary_id, source_code: codes)
          .select(Sequel[:source_vocabulary_id].as(:vocabulary_id), Sequel[:source_code].as(:concept_code), Sequel[:source_code_description].as(:concept_text))
          .from_self
        standards.union(sources).order(:concept_code, :concept_text).from_self.select_group(:vocabulary_id, :concept_code).select_append(Sequel.function(:min, :concept_text).as(:concept_text)).from_self
      end

      def information_period_where_clause(arguments)
        return if arguments.empty?
        { plan_source_value: arguments }
      end
    end
  end
end

