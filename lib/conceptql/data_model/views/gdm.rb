module ConceptQL
  module DataModel
    module Views
      class View
        attr_reader :base_name, :opts
        attr_accessor :primary_table, :primary_table_alias, :aliaz, :version

        def initialize(base_name, opts = {}, &block)
          @opts = opts
          @base_name = base_name
          @view_columns = {}
          @ds_block = proc { |aliased_table, _, db, _| db[aliased_table] }
          block.call(self) if block
        end

        def name
          sprintf("%s_v%d", base_name.downcase, version || 1).to_sym
        end

        def ds(&block)
          @ds_block = block
        end

        def selection(db, rdbms)
          mapped_cols = @view_columns.map do |aliaz, def_block|
            args = [primary_alias, db, rdbms].take(def_block.arity)
            [aliaz, Sequel.expr(def_block.call(*args)).as(aliaz)]
          end.to_h

          table_cols =
            if primary_table
              db[primary_table].columns.map do |col|
                [col, primary_alias[col].as(col)]
              end
            end.to_h

          table_cols.merge(mapped_cols).values
        end

        def sql(db, rdbms)
          @ds_block.call(aliased_primary_table, primary_alias, db, rdbms).select(*selection(db, rdbms))
        end

        def new_view_column(name, &def_block)
          @view_columns[name] = def_block
        end

        def aliased_primary_table
          Sequel[primary_table].as(primary_table_alias)
        end

        def primary_alias
          Sequel[primary_table_alias]
        end

        def columns
          @view_columns.map do |aliaz, _|
            { name: aliaz, type: Scope::COLUMN_TYPES[aliaz] }
          end
        end

        def remake!(db, dm)
          db.drop_view(name, if_exists: true)
          db.create_view(name, sql(db, dm.rdbms))
        end

        def to_h
          opts.merge({
            name: name,
            columns: columns,
            aliaz: aliaz,
            primary_table: primary_table
          }.compact)
        end
      end

      class Gdm
        attr_reader :views

        def initialize
          @views = []
          make_views
        end

        def new_view(name, opts = {}, &block)
          views << View.new(name, opts, &block)
        end

        def make(db, rdbms, opts = {})
          views.each { |v| v.remake!(db, rdbms, opts) }
        end

        def make_views
          ["SNF", "hospice", "inpatient"].map do |collection_type|
            new_view("#{collection_type.downcase}_utilizations") do |v|
              v.primary_table = :collections
              v.primary_table_alias = :cl
              v.aliaz = "#{collection_type}_cql".downcase.to_sym


              v.ds do |aliased_table, pa, db, rdbms|
                lexicon = new_lexicon(db)

                ancestor_ids = lexicon.concepts("JIGSAW_FILE_PROVENANCE_TYPE", collection_type).select(:id)
                descendant_ids = lexicon.descendants_of(ancestor_ids).select(:descendant_id)
                primary_ids = lexicon.concepts("JIGSAW_CODE_PROVENANCE_TYPE", "primary").select(:id)

                primary_concepts = db[:clinical_codes].from_self(alias: :pcc)
                  .join(:contexts, { Sequel[:pcn][:id] => Sequel[:pcc][:context_id] }, table_alias: :pcn)
                  .join(:concepts, { Sequel[:pco][:id] => Sequel[:pcc][:clinical_code_concept_id] }, table_alias: :pco)
                  .where(provenance_concept_id: primary_ids)
                  .select(Sequel[:pcn][:collection_id], Sequel[:pco][:concept_code], Sequel[:pco][:vocabulary_id])


                db[aliased_table]
                  .join(:admission_details, { Sequel[:ad][:id] => Sequel[pa][:admission_detail_id] }, table_alias: :ad)
                  .left_join(:contexts, { Sequel[:cn][:collection_id] => Sequel[pa][:id] }, table_alias: :cn)
                  .left_join(:concepts, { Sequel[:ad][:admit_source_concept_id] => Sequel[:asc][:id] }, table_alias: :asc)
                  .left_join(:concepts, { Sequel[:ad][:discharge_location_concept_id] => Sequel[:dlc][:id] }, table_alias: :dlc)
                  .left_join(primary_concepts, { Sequel[:pcon][:collection_id] => Sequel[pa][:id] }, table_alias: :pcon)
                  .where(Sequel[:cn][:source_type_concept_id] => descendant_ids)
              end

              v.new_view_column(:person_id) { |pa| pa[:patient_id] }
              v.new_view_column(:criterion_id) { |pa| pa[:id] }
              v.new_view_column(:criterion_table) { Sequel.cast_string("collections") }
              v.new_view_column(:criterion_domain) { Sequel.cast_string("condition_occurrence") }
              v.new_view_column(:start_date) { Sequel[:ad][:admission_date] }
              v.new_view_column(:end_date) { Sequel[:ad][:discharge_date] }
              v.new_view_column(:length_of_stay) { |pa, db, rdbms| ((rdbms.days_between(Sequel[:ad][:admission_date], Sequel[:ad][:discharge_date])) + 1) }
              v.new_view_column(:admission_source) { Sequel[:asc][:concept_code] }
              v.new_view_column(:discharge_location) { Sequel[:dlc][:concept_code] }
              v.new_view_column(:source_value) { Sequel[:pcon][:concept_code] }
              v.new_view_column(:source_vocabulary_id) { Sequel[:pcon][:vocabulary_id] }
            end
          end
        end

        def new_lexicon(db)
          Lexicon.new(db)
        end
      end
    end
  end
end
