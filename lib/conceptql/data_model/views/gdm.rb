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
                source_type_id = lexicon.concepts("JIGSAW_FILE_PROVENANCE_TYPE", collection_type).select_map(:id)
                all_source_type_ids = lexicon.descendants_of(source_type_id).select_map(:descendant_id)
                primary_id = lexicon.concepts("JIGSAW_CODE_PROVENANCE_TYPE", "primary").select_map(:id)
                all_primary_ids = lexicon.descendants_of(primary_id).select_map(:descendant_id)
                condition_domains = lexicon.lexicon_db[:vocabularies].where(domain: 'condition_occurrence').select_map(:id)

                # Get primary diagnosis codes
                primary_concepts = db[Sequel[:clinical_codes].as(:pcc)]
                  .where(provenance_concept_id: all_primary_ids, Sequel[:pcc][:clinical_code_vocabulary_id] => condition_domains)
                  .select(
                    Sequel[:pcc][:collection_id].as(:collection_id),
                    Sequel[:pcc][:clinical_code_source_value].as(:concept_code),
                    Sequel[:pcc][:clinical_code_vocabulary_id].as(:vocabulary_id))
                  .order(Sequel[:pcc][:collection_id], Sequel[:pcc][:clinical_code_concept_id])
                  .from_self
                  .select_group(:collection_id)
                  .select_append(
                    Sequel.function(:min, :concept_code).as(:concept_code),
                    Sequel.function(:min, :vocabulary_id).as(:vocabulary_id)
                  )


                db[:collections].from_self(alias: :cl)
                  .join(:admission_details, { Sequel[:ad][:id] => Sequel[:cl][:admission_detail_id] }, table_alias: :ad)
                  .left_join(:contexts, { Sequel[:cn][:collection_id] => Sequel[:cl][:id] }, table_alias: :cn)
                  .left_join(:concepts, { Sequel[:ad][:admit_source_concept_id] => Sequel[:asc][:id] }, table_alias: :asc)
                  .left_join(:concepts, { Sequel[:ad][:discharge_location_concept_id] => Sequel[:dlc][:id] }, table_alias: :dlc)
                  .left_join(primary_concepts, { Sequel[:pcon][:collection_id] => Sequel[:cl][:id] }, table_alias: :pcon)
                  .where(Sequel[:cn][:source_type_concept_id] => all_source_type_ids)
              end

              v.new_view_column(:start_date, Sequel[:cl][:start_date])
              v.new_view_column(:end_date, Sequel[:cl][:end_date])
              v.new_view_column(:admission_date, Sequel[:ad][:admission_date])
              v.new_view_column(:discharge_date, Sequel[:ad][:discharge_date])
              v.new_view_column(:length_of_stay) { |pa, db, rdbms| ((rdbms.days_between(Sequel[:ad][:admission_date], Sequel[:ad][:discharge_date])) + 1) }
              v.new_view_column(:admission_source_value, Sequel[:asc][:concept_code])
              v.new_view_column(:admission_source_description, Sequel[:asc][:concept_text])
              v.new_view_column(:discharge_location_source_value, Sequel[:dlc][:concept_code])
              v.new_view_column(:discharge_location_source_description, Sequel[:dlc][:concept_text])
              v.new_view_column(:source_value, Sequel[:pcon][:concept_code])
              v.new_view_column(:source_vocabulary_id, Sequel[:pcon][:vocabulary_id])
              v.new_view_column(:person_id, Sequel[:cl][:patient_id])
              v.new_view_column(:criterion_id, Sequel[:cl][:id])
              v.new_view_column(:criterion_table, Sequel.cast_string("collections"))
              v.new_view_column(:criterion_domain, Sequel.cast_string("condition_occurrence"))
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

          new_view("providers_join_view") do |v|
            provs_alias = :provs
            provs_table = Sequel[:practitioners].as(provs_alias)

            v.ds do |_, pa, db, rdbms|
              clinical_codes_practitioners = db[provs_table]
                .join(Sequel[:contexts_practitioners], {Sequel[provs_alias][:id] => Sequel[:con_prov][:practitioner_id]}, table_alias: :con_prov)
                .join(Sequel[:clinical_codes], {Sequel[:cc][:context_id] => Sequel[:con_prov][:context_id]}, table_alias: :cc)
                .select(
                  Sequel[:cc][:id].as(:criterion_id),
                  Sequel.cast_string("clinical_codes").as(:criterion_table),
                  Sequel[provs_alias][:id].as(:provider_id),
                  Sequel[provs_alias][:id].as(:specialty_concept_id)
                )
              deaths_practitioners = db[provs_table]
                .join(Sequel[:deaths], {Sequel[provs_alias][:id] => Sequel[:death_prov][:practitioner_id]}, table_alias: :death_prov)
                .select(
                  Sequel[:death_prov][:id].as(:criterion_id),
                  Sequel.cast_string("deaths").as(:criterion_table),
                  Sequel[provs_alias][:id].as(:provider_id),
                  Sequel[provs_alias][:id].as(:specialty_concept_id)
                )
              patients_practitioners = db[provs_table]
                .join(Sequel[:patients], {Sequel[provs_alias][:id] => Sequel[:patient_prov][:practitioner_id]}, table_alias: :patient_prov)
                .select(
                  Sequel[:patient_prov][:id].as(:criterion_id),
                  Sequel.cast_string("patients").as(:criterion_table),
                  Sequel[provs_alias][:id].as(:provider_id),
                  Sequel[provs_alias][:id].as(:specialty_concept_id)
                )

              clinical_codes_practitioners
                .union(deaths_practitioners, all: true)
                .union(patients_practitioners, all: true)
                .from_self
            end

            v.new_view_column(:criterion_id, Sequel[:criterion_id])
            v.new_view_column(:criterion_table, Sequel[:criterion_table])
            v.new_view_column(:provider_id, Sequel[:provider_id])
            v.new_view_column(:specialty_concept_id, Sequel[:specialty_concept_id])
          end

          new_view("place_of_service_join_view") do |v|
            cons_alias = :cons
            cons_table = Sequel[:contexts].as(cons_alias)
            v.ds do |_, pa, db, rdbms|
              db[cons_table]
                .join(Sequel[:clinical_codes], {Sequel[:cc][:context_id] => Sequel[:cons][:id]}, table_alias: :cc)
            end

            v.new_view_column(:criterion_id, Sequel[:cc][:id])
            v.new_view_column(:criterion_table, Sequel.cast_string("clinical_codes"))
            v.new_view_column(:pos_concept_id, Sequel[cons_alias][:pos_concept_id])
          end

          new_view("provenance_join_view") do |v|
            cons_alias = :cons
            cons_table = Sequel[:contexts].as(cons_alias)
            v.ds do |_, pa, db, rdbms|
              db[cons_table]
                .join(Sequel[:clinical_codes], {Sequel[:cc][:context_id] => Sequel[:cons][:id]}, table_alias: :cc)
            end

            v.new_view_column(:criterion_id, Sequel[:cc][:id])
            v.new_view_column(:criterion_table, Sequel.cast_string("clinical_codes"))
            v.new_view_column(:file_provenance_type, Sequel[cons_alias][:source_type_concept_id])
            v.new_view_column(:code_provenance_type, Sequel[:cc][:provenance_concept_id])
          end
        end

        def new_lexicon(db)
          Lexicon.new(db)
        end
      end
    end
  end
end
