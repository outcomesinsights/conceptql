module ConceptQL
  module DataModel
    module Views
      class View
        attr_reader :base_name, :opts, :columns
        attr_accessor :primary_table, :primary_table_alias, :aliaz, :version, :schema

        class ViewColumn
          attr_reader :name
          attr_accessor :table
          def initialize(name, definition, &def_block)
            @name = name
            @definition = definition
            @def_block = def_block
          end

          def to_column(primary_alias, db, rdbms)
            [name, Sequel.expr(get_def(primary_alias, db, rdbms)).as(name)]
          end

          def get_def(primary_alias, db, rdbms)
            return @definition if @definition
            args = [primary_alias, db, rdbms].take(@def_block.arity)
            @def_block.call(*args)
          end
        end

        def initialize(base_name, opts = {}, &block)
          @opts = opts
          @base_name = base_name
          @columns = []
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
          mapped_cols = @columns.map do |vc|
            vc.to_column(primary_alias, db, rdbms)
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

        def new_view_column(name, definition = nil, &def_block)
          @columns << ViewColumn.new(name, definition, &def_block).tap do |v|
            v.table = self
          end
        end

        def aliased_primary_table
          Sequel[primary_table].as(primary_table_alias)
        end

        def primary_alias
          Sequel[primary_table_alias]
        end

        def setup!
          #do nothing
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
              v.new_view_column(:criterion_table, Sequel.cast_string("collections"))
              v.new_view_column(:criterion_domain, Sequel.cast_string("condition_occurrence"))
              v.new_view_column(:start_date, Sequel[:ad][:admission_date])
              v.new_view_column(:end_date, Sequel[:ad][:discharge_date])
              v.new_view_column(:length_of_stay) { |pa, db, rdbms| ((rdbms.days_between(Sequel[:ad][:admission_date], Sequel[:ad][:discharge_date])) + 1) }
              v.new_view_column(:admission_source, Sequel[:asc][:concept_code])
              v.new_view_column(:discharge_location, Sequel[:dlc][:concept_code])
              v.new_view_column(:source_value, Sequel[:pcon][:concept_code])
              v.new_view_column(:source_vocabulary_id, Sequel[:pcon][:vocabulary_id])
            end
          end

          new_view("druggish") do |v|
            v.primary_table = :clinical_codes
            v.primary_table_alias = :dedcc

            v.ds do |aliased_table, pa, db, rdbms|
             db[aliased_table]
              .left_join(Sequel[:drug_exposure_details].as(:de), Sequel[pa][:drug_exposure_detail_id] => Sequel[:de][:id])
              .left_join(Sequel[:concepts].as(:dose_con), Sequel[:de][:dose_unit_concept_id] => Sequel[:dose_con][:id])
              .left_join(Sequel[:concepts].as(:ing_con), Sequel[pa][:clinical_code_concept_id] => Sequel[:ing_con][:id])
            end

            v.new_view_column(:criterion_id) { |pa| pa[:id] }
            v.new_view_column(:criterion_table, Sequel.cast_string("clinical_codes"))
            v.new_view_column(:drug_amount, Sequel[:de][:dose_value])
            v.new_view_column(:drug_amount_units, Sequel[:dose_con][:concept_text])
            v.new_view_column(:drug_name, Sequel[:ing_con][:concept_text])
            v.new_view_column(:drug_days_supply, Sequel[:de][:days_supply])
            v.new_view_column(:drug_quantity, Sequel[:dedcc][:quantity])
          end

          new_view("labish") do |v|
            v.primary_table = :clinical_codes
            v.primary_table_alias = :labcc

            v.ds do |aliased_table, pa, db, rdbms|
             db[aliased_table]
              .left_join(Sequel[:measurement_details].as(:md), Sequel[pa][:measurement_detail_id] => Sequel[:md][:id])
              .left_join(Sequel[:concepts].as(:unit_con), Sequel[:md][:unit_concept_id] => Sequel[:unit_con][:id])
              .left_join(Sequel[:concepts].as(:result_con), Sequel[:md][:result_as_concept_id] => Sequel[:result_con][:id])
            end

            v.new_view_column(:criterion_id) { |pa| pa[:id] }
            v.new_view_column(:criterion_table, Sequel.cast_string("clinical_codes"))
            v.new_view_column(:lab_value_as_number, Sequel[:md][:result_as_number])
            v.new_view_column(:lab_value_as_string, Sequel[:md][:result_as_string])
            v.new_view_column(:lab_value_as_concept_id, Sequel[:result_con][:concept_text])
            v.new_view_column(:lab_unit_source_value, Sequel[:unit_con][:concept_text])
            v.new_view_column(:lab_range_low, Sequel[:md][:normal_range_low])
            v.new_view_column(:lab_range_high, Sequel[:md][:normal_range_high])
          end
        end

        def new_lexicon(db)
          Lexicon.new(db)
        end
      end
    end
  end
end
