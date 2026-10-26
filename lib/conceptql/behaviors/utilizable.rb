# frozen_string_literal: true

require "active_support/concern"

module ConceptQL
  module Behaviors
    module Utilizable
      extend ActiveSupport::Concern
      include ConceptQL::Behaviors::Windowable

      included do
        domains :condition_occurrence
        category "Select by Property"
        basic_type :selection
        validate_no_upstreams
        validate_no_arguments

        require_column :admission_date
        require_column :discharge_date
        require_column :length_of_stay
        require_column :admission_source_value
        require_column :admission_source_description
        require_column :discharge_location_source_value
        require_column :discharge_location_source_description
        require_column :primary_concept_id
      end

      def column_family
        "inpatient"
      end

      # The operators that include this register for gdm and gdm_wide only.
      def query(db)
        gdm_it(db)
      end

      def collection_type
        raise NotImplementedError
      end

      # With the Database's share_utilization option, the list is read from a
      # table that every statement on the Database shares. The WITH entry only
      # carries the list to Scope#with_ctes, which takes it out of the SQL and
      # creates the table when the query first reads rows.
      def evaluate(db)
        cdb = nodifier.cdb
        return super unless cdb.opts[:share_utilization]

        list = select_it(query(db))
        name = cdb.shared_utilization_table(list, scope)
        db[name].with(name, list, Scope::SHARED_TABLE => true)
      end

      def gdm_it(db)
        source_type_id = dm.concept_ids(db, dm.file_provenance_types_vocab, collection_type)
        all_source_type_ids = dm.descendants_of(db, source_type_id)
        primary_id = dm.concept_ids(db, dm.code_provenance_types_vocab, "primary")
        all_primary_ids = dm.descendants_of(db, primary_id)
        # condition_vocabularies = dm.vocabularies_query.where(domain: 'condition_occurrence').select_map(:id)

        return gdm_wide_it(db, all_primary_ids, all_source_type_ids) if wide?

        # Get primary diagnosis codes
        primary_concepts = rdbms.primary_concepts(db, all_primary_ids)

        relevant_contexts = db[Sequel[:contexts].as(:cn)]
                            .where(Sequel[:cn][:source_type_concept_id] => all_source_type_ids)
                            .select(:collection_id)

        db[:collections].from_self(alias: :cl)
                        .then { |cl| restrict_to_window_persons(cl, Sequel[:cl][:patient_id]) }
                        .join(:admission_details, { Sequel[:ad][:id] => Sequel[:cl][:admission_detail_id] }, table_alias: :ad)
                        .left_join(dm.name_concepts_table(db), { Sequel[:ad][:admit_source_concept_id] => Sequel[:asc][:id] }, table_alias: :asc)
                        .left_join(dm.name_concepts_table(db), { Sequel[:ad][:discharge_location_concept_id] => Sequel[:dlc][:id] }, table_alias: :dlc)
                        .left_join(primary_concepts, { Sequel[:pcon][:collection_id] => Sequel[:cl][:id] }, table_alias: :pcon)
                        .where(Sequel[:cl][:id] => relevant_contexts)
                        .select(
                          Sequel[:cl][:start_date].as(:collection_start_date),
                          Sequel[:cl][:end_date].as(:collection_end_date),
                          Sequel[:ad][:admission_date].as(:admission_date),
                          Sequel[:ad][:discharge_date].as(:discharge_date),
                          Sequel[:asc][:concept_code].as(:admission_source_value),
                          Sequel[:asc][:concept_text].as(:admission_source_description),
                          Sequel[:dlc][:concept_code].as(:discharge_location_source_value),
                          Sequel[:dlc][:concept_text].as(:discharge_location_source_description),
                          Sequel[:pcon][:concept_id].as(:primary_concept_id),
                          Sequel[:pcon][:concept_code].as(:source_value),
                          Sequel[:pcon][:vocabulary_id].as(:source_vocabulary_id),
                          Sequel[:cl][:patient_id].as(:patient_id),
                          Sequel[:cl][:id].as(:collection_id)
                        )
                        .select_append(Sequel[:ROW_NUMBER].function.over(
                          partition: [ :admission_detail_id ],
                          order: [
                            Sequel[:pcon][:is_primary].desc,
                            Sequel[:cl][:id],
                            Sequel[:pcon][:concept_code]
                          ]
                        ).as(:nummy))
                        .from_self
                        .where(nummy: 1)
      end

      def gdm_wide_it(db, all_primary_ids, all_source_type_ids)
        # Emit `CASE WHEN provenance_concept_id IN (...) THEN 1 ELSE 0 END`.
        # The previous multi-WHEN form (`Sequel.case({{prov=>id1}=>1, {prov=>id2}=>1, ...}, 0)`)
        # is mis-evaluated by Spark 3.3.2 when its result feeds the outer
        # `CASE is_primary WHEN 1 THEN col ELSE NULL END` below. See conceptql-pk7.
        is_primary =
          if all_primary_ids.empty?
            Sequel[0]
          else
            Sequel.case(
              [ [ { Sequel[:provenance_concept_id] => all_primary_ids }, 1 ] ],
              0
            )
          end

        db[:observations]
          .then { |observations| restrict_to_window_persons(observations, :patient_id) }
          .where(source_type_concept_id: all_source_type_ids)
          .exclude(admit_admission_date: nil)
          .select_append(
            is_primary.as(:is_primary)
          )
          .from_self
          # One admission has many rows with the same concept on different
          # line dates. The unique id ends the ORDER BY so the kept row is the
          # same on every run, and admission_end_date takes the latest end_date
          # over all of the admission's rows, not the kept row's. See conceptql-evk.
          .select_append(
            Sequel[:ROW_NUMBER].function.over(
              partition: [ :admission_detail_id ],
              order: [ Sequel[:is_primary].desc, Sequel[:collection_id], Sequel[:clinical_code_concept_id], Sequel[:id] ]
            ).as(:nummy),
            Sequel.function(:max, :end_date).over(partition: [ :admission_detail_id ]).as(:admission_end_date)
          )
          .from_self
          .where(nummy: 1)
          .from_self
          .left_join(dm.name_concepts_table(db), { Sequel[:admit_source_concept_id] => Sequel[:asc][:id] }, table_alias: :asc)
          .left_join(dm.name_concepts_table(db), { Sequel[:discharge_location_concept_id] => Sequel[:dlc][:id] }, table_alias: :dlc)
          .select_append(
            Sequel[:asc][:concept_code].as(:admission_source_value),
            Sequel[:asc][:concept_text].as(:admission_source_description),
            Sequel[:dlc][:concept_code].as(:discharge_location_source_value),
            Sequel[:dlc][:concept_text].as(:discharge_location_source_description),
            Sequel.case({ 1 => :clinical_code_concept_id }, nil, :is_primary).as(:primary_concept_id),
            Sequel.case({ 1 => :clinical_code_source_value }, nil, :is_primary).as(:source_value),
            Sequel.case({ 1 => :clinical_code_vocabulary_id }, nil, :is_primary).as(:source_vocabulary_id)
          )
          .from_self
      end

      # Keep only the persons that the scope's table windows cover, before the
      # ROW_NUMBER over admission_detail_id. Without this, Spark numbers every
      # inpatient row in the database and applies the window join afterwards.
      # Output is unchanged because one admission never belongs to two persons
      # (Ryan, 2026-10-14), so each ROW_NUMBER partition is kept or dropped whole.
      def restrict_to_window_persons(ds, person_column)
        return ds if skip_windows?

        scope.windows.grep(Window::Table).inject(ds) do |restricted, window|
          restricted.where(person_column => window.person_ids(restricted.db))
        end
      end

      def table
        :collections
      end

      def override_columns
        return unless gdm?

        {
          length_of_stay: (rdbms.days_between(Sequel[:admission_date],
                                              discharge_date_column) + 1).as(:length_of_stay),
          criterion_table: Sequel.cast_string("collections").as(:criterion_table),
          criterion_domain: Sequel.cast_string("condition_occurrence").as(:criterion_domain),
          admission_source_value: Sequel[:admission_source_value],
          admission_source_description: Sequel[:admission_source_description],
          discharge_location_source_value: Sequel[:discharge_location_source_value],
          discharge_location_source_description: Sequel[:discharge_location_source_description],
          admission_date: Sequel[:admission_date],
          discharge_date: discharge_date_column.as(:discharge_date),
          person_id: Sequel[:patient_id].as(:person_id),
          criterion_id: Sequel[:collection_id].as(:criterion_id),
          start_date: Sequel[:collection_start_date].as(:start_date),
          end_date: Sequel[:collection_end_date].as(:end_date),
          primary_concept_id: Sequel[:primary_concept_id],
          source_value: Sequel[:source_value].as(:source_value),
          source_vocabulary_id: Sequel[:source_vocabulary_id].as(:source_vocabulary_id)
        }
      end

      # gdm_wide's AdmissionDateQueryModifier falls back to the kept row's own
      # end_date when the admission has no discharge date. An admission falls
      # back to its latest end_date instead (Ryan, 2026-10-16). See conceptql-evk.
      def discharge_date_column
        return Sequel[:discharge_date] unless wide?

        Sequel.function(:coalesce, :admit_discharge_date, :admission_end_date, :discharge_date)
      end
    end
  end
end
