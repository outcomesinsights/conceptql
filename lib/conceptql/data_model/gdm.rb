require_relative "base"

module ConceptQL
  module Models
    class Schema < FauxModel
      has_many :tables
      has_many :views, class_name: "Table"

      def initialize(*args)
        super
        self.tables ||= []
        self.views ||= []
        update_relations!
      end

      def update_relations!
        relations.each do |relation|
          relation.schema = self 
          relation.setup! 
          self[relation.name] = relation
        end 
      end

      def remake_views!(db)
        views.each { |v| v.remake!(db, dm) }
      end

      def tables_by_column(*column_names)
        @tables_by_column ||= tables.each.with_object({}) do |table, h|
          table.columns.each do |column|
            (h[column.name] ||= []) << column.table
          end
        end

        @tables_by_column.values_at(*column_names).flatten.uniq
      end

      def views_by_column(*column_names)
        @views_by_column ||= views.each.with_object({}) do |view, h|
          view.columns.each do |column|
            (h[column.name] ||= []) << column.table
          end
        end

        @views_by_column.values_at(*column_names).flatten.uniq
      end

      def pretty_print(pp)
        pp.object_group self do
          pp.comma_breakable
          pp.text "@tables="
          pp.pp tables.map(&:name)
        end
      end

      def relations
        tables + views
      end
    end

    class Column < FauxModel
      def to_column
        Sequel[source_column.name].as(name)
      end

      def pretty_print(pp)
        pp.object_group self do
          %i[name type null foreign_key].each do |meth|
            pp.comma_breakable
            pp.text "@#{meth}="
            pp.pp self[meth]
          end

          %i[table foreign_table].each do |meth|
            next unless self[meth]
            pp.breakable
            pp.text "@#{meth}="
            pp.pp self[meth].name
          end
        end
      end
    end

    class NullColumn
      attr_reader :name, :type
      attr_accessor :table, :mapped_to

      def initialize(name, type, table)
        @name = name
        @type = type
        @table = table
        @mapped_to = [name]
      end

      def foreign_key
      end

      def to_column
        case type
        when :String, "String"
          Sequel.cast_string(nil)
        else
          Sequel[nil]
        end.as(name)
      end
    end

    class Table < FauxModel
      has_many :columns

      def setup!
        #puts name
        #binding.pry if name == :patients_cql_view_v1
        columns.each do |column|
          column.table = self
          column.mapped_to = (column.mapped_to || []) | [column.name]
          column.foreign_table = schema[column.foreign_key.to_sym] if column.foreign_key
          self[column.name] = column
        end
      end

      def foreign_keys
        columns.select { |c| c.foreign_key }
      end

      def primary_key
        columns.find { |c| c.primary_key }
      end

      def matching_columns(regexp)
        columns.select { |c| c.name =~ regexp }
      end

      def as_name(op)
        sprintf("%s_%s_%03d", name, op.op_name, counter).downcase
      end

      def remake!(db, dm)
        db.drop_view(name, if_exists: true)
        db.create_view(name, db[source_table.name].select(*columns_as_sql(dm)))
      end

      def null_column(name, type = :String)
        columns << NullColumn.new(name, type, self)
      end

      def columns_as_sql(dm)
        other_columns = [ Sequel.cast_string(source_table.name.to_s).as(:criterion_table) ]

        if cd = criterion_domain_column(dm)
          other_columns << Sequel.cast_string(cd).as(:criterion_domain) 
        end
        
        columns_hash.map do |name, info|
          info.to_column 
        end + other_columns
      end

      def columns_hash
        @columns_hash ||= columns.each.with_object({}) do |column, h|
          ((column.mapped_to || []) | [column.name]).each do |name|
            h[name] = column
          end
        end
      end

      def criterion_domain_column(dm)
        if source_table.name == :clinical_codes
          lexicon = dm.lexicon
          vocabs_to_domains = lexicon.vocabularies_query
            .select_hash_groups(:domain, :id)
            .invert.map do |vocab_ids, domain|
            [ { clinical_code_vocabulary_id: vocab_ids }, domain ]
          end
          return Sequel.case(vocabs_to_domains, Sequel.cast_string("condition_occurrence"))
        end
        return domain_lookup[source_table.name]
      end

      def domain_lookup
        {
          patients: "person",
          deaths: "death",
          information_periods: "information_period",
          collections: "condition_occurrence",
        }
      end

      def counter
        @counter ||= 0
        @counter += 1
      end

      def view
        @view ||= Table.new(name: "#{name}_cql_view_v1".to_sym, 
                            source_table: self,
                            columns: columns_hash.map do |name, column|
          Column.new(
            name: name,
            type: column.type,
            comment: column.comment,
            foreign_key: column.foreign_key,
            source_column: column
          )
        end)
      end

      def pretty_print(pp)
        pp.object_group self do
          pp.breakable
          pp.text "@name="
          pp.pp name

          pp.breakable
          pp.text "@columns="
          pp.pp columns.map(&:name)
        end
      end
    end
  end

  module DataModel

    class Gdm < Base
      def query_modifier_for(column)
        {
          visit_source_concept_id: ConceptQL::QueryModifiers::Gdm::PoSQueryModifier,
          provider_id: ConceptQL::QueryModifiers::Gdm::ProviderQueryModifier,
          drug_name: ConceptQL::QueryModifiers::Gdm::DrugQueryModifier,
          admission_date: ConceptQL::QueryModifiers::Gdm::AdmissionDateQueryModifier,
          provenance_type: ConceptQL::QueryModifiers::Gdm::ProvenanceQueryModifier,
          value_as_number: ConceptQL::QueryModifiers::Gdm::LabQueryModifier,
        }[column]
      end

      def views
        @views ||= Views::Gdm.new
      end

      def nschema
        Models::Schema.new(tables: SCHEMAS[:gdm_arrayed], dm: self).tap do |schema|
          #, views: views.views.map(&:to_h)
          mapify(schema)
        end
      end

      def mapify(schema)
        schema.patients.id.mapped_to << :person_id
        schema.tables_by_column(:patient_id).each do |table|
          table.patient_id.mapped_to << :person_id
        end

        schema.tables_by_column(:id).each do |table|
          table.id.mapped_to << :criterion_id
        end

        schema.tables.each do |table|
          start_cols = table.matching_columns(/start_date/).each do |column|
            column.mapped_to << :start_date
          end

          end_cols = table.matching_columns(/end_date/).each do |column|
            column.mapped_to << :end_date
          end

          (table.matching_columns(/(\b|_)date\Z/) - start_cols - end_cols).each do |column|
            column.mapped_to << :start_date
            column.mapped_to << :end_date
          end
        end

        # For views that have a primary table, set the view up to pass-thru
        # all columns from that table
=begin
        schema.relations.select(&:primary_table).each do |relation|
          table = schema[relation[:primary_table]]
          pass_thru_columns = (table.columns.map(&:name) - relation.columns.map(&:name)).map do |column_name|
            table[column_name]
          end
          relation.columns += pass_thru_columns
          pass_thru_columns.each do |pass_thru_column|
            relation[pass_thru_column.name] = pass_thru_column
          end
        end
=end

        schema.clinical_codes.clinical_code_concept_id.mapped_to << :concept_id
        schema.clinical_codes.clinical_code_source_value.mapped_to << :source_value
        schema.clinical_codes.clinical_code_vocabulary_id.mapped_to << :source_vocabulary_id

        schema.patients.view.null_column(:source_value)
        schema.patients.view.null_column(:source_vocabulary_id)

        schema.deaths.view.null_column(:source_value)
        schema.deaths.view.null_column(:source_vocabulary_id)

        schema.information_periods.view.null_column(:source_value)
        schema.information_periods.view.null_column(:source_vocabulary_id)

        schema.tables.each do |table|
          table.columns.each do |column|
            column.mapped_to.each do |mapping|
              table[mapping] = column
            end
          end
        end
        
        schema.tables.each do |table|
          schema.views << table.view
        end
        schema.views += views.views

        schema.update_relations!

        schema.clinical_codes_cql_view_v1.aliaz = :cc_cql
        schema.deaths_cql_view_v1.aliaz = :deaths_cql
        schema.patients_cql_view_v1.aliaz = :people_cql

        # Apply table aliases to schema
        schema.relations.each do |relation|
          if aliaz = relation.aliaz
            schema[aliaz] = relation
          end
        end
      end

      def wrappers
        @wrappers = {
          lab_value_as_number: Class.new do
            def wrap(ds, opts = {})
              lab_value_column = Sequel.function(
                :coalesce,
                Sequel[:og][:lab_value_as_number],
                Sequel[:lvan_join][:lab_value_as_number]
              )
              ds.from_self(alias: :og)
                .left_join(join_view_name, join_clause, table_alias: :lvan_join)
                .auto_column(:lab_value_as_number, lab_value_column)
            end

            def join_view_name
              :labish_v1
            end

            def join_clause
              %i[criterion_id criterion_table].map do |c|
                [Sequel[:og][c], Sequel[:lvan_join][c]]
              end.to_h
            end
          end
        }
      end

      def wrap(ds, opts)
        wrappers[opts[:for]].new.wrap(ds, opts)
      end

      def make_table_id
        :id
      end

      def person_id(table = nil)
        return :id if table == :patients
        :patient_id
      end

      def person_table
        :patients
      end

      def views
        DataModel::Views::Gdm.new
      end

      def period_table
        :information_periods
      end

      def criterion_id
        Sequel.expr(:id).as(:criterion_id)
      end

      def table_id(table = nil)
        return :criterion_id if table.nil?
        Sequel.expr(make_table_id(table)).as(:criterion_id)
      end

      def make_table_id(table)
        :id
      end

      def fk_by_domain(domain)
        table = table_by_domain(domain)
        (table.to_s.gsub(/_id/, "").chomp("s") + "_id").to_sym
      end

      def pk_by_domain(domain)
        :id
      end

      def table_by_domain(table)
        return nil unless table
        case table
        when :person, :patients
          :patients
        when :death, :deaths
          :deaths
        when :observation_period, :information_periods
          :information_periods
        when :provider, :practitioners
          :practitioners
        when :collections
          :collections
        else
          :clinical_codes
        end
      end

      def table_to_domain(table)
        {
          patients: :person,
          deaths: :death,
          information_periods: :observation_period,
          practitioners: :provider
        }[table]
      end

      def person_id_column(table)
        col =
          if table.to_sym == :patients
            :id
          else
            :patient_id
          end
        Sequel.identifier(col).as(:person_id)
      end

      def data_model
        :gdm
      end

      def start_date_column(query, domain)
        start_date_columns[domain]
      end

      def end_date_column(query, domain)
        end_date_columns[domain]
      end

      def id_column(table)
        :id
      end

      def pos_table_fk
        :context_id
      end

      def source_vocabulary_ids
        @source_vocabulary_ids = assign_column_to_table do |table, columns|
          next if %w(patients death).any? { |tn| table.to_s =~ /#{tn}/ }
          reggy = /#{table.to_s.split("_").first}_vocabulary_id/
          column = columns.select { |k| k =~ reggy }.first
          column ||= columns.select { |k| k =~ /_vocabulary_id/ }.first
        end
      end

      # The mappings table will tell us what other concepts have been directly
      # mapped to the concepts passed in
      def related_concept_ids(db, *ids)

        ids = ids.flatten
        other_ids = db[:mappings].where(concept_2_id: ids).where{Sequel.function(:lower, :relationship_id) =~ 'is_a'}.select_map(:concept_1_id)
        other_ids + ids
      end

      def table_is_missing?(db)
        !db.table_exists?(:concepts)
      end

      def code_provenance_type(query, domain)
        :provenance_concept_id
      end

      def file_provenance_type(query, domain)
        :source_type_concept_id
      end

      def concepts_ds(db, vocabulary_id, codes)
        db[:concepts]
          .where(vocabulary_id: vocabulary_id, concept_code: codes)
          .select(Sequel[:concept_code].as(:concept_code), Sequel[:concept_text].as(:concept_text))
          .from_self
      end

      def information_period_where_clause(arguments)
        return if arguments.empty?
        { information_type_concept_id: arguments.map(&:to_i) }
      end
    end
  end
end
