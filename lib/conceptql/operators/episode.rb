# frozen_string_literal: true

require_relative "pass_thru"

module ConceptQL
  module Operators
    class Episode < PassThru
      register __FILE__
      effects :aggregate

      desc "Merges each patient's results into episodes: spans of time in which the results are close together. " \
           "For example, it can turn a set of prescriptions into the spans of time in which a patient takes a drug."
      returns "One result for each episode. Its start_date is the earliest start_date in the episode, " \
              "and its end_date is the latest end_date. Its criterion_table and criterion_domain are episode, " \
              "and its criterion_id is 0, because an episode merges several results."
      example "Episodes of diabetes diagnoses", [ "episode", [ "icd9", "250.00" ], { "gap_of" => "90" } ]

      validate_one_upstream
      option :gap_of, type: :integer,
                      instructions: "Enter a number of days. A result stays in the current episode when it starts no more than this many days after the latest end date of the earlier results. The default is 0.",
                      meaning: "The largest gap in days that stays in the same episode. The operator orders each " \
                               "patient's results by start_date and then by end_date. A result stays in the current " \
                               "episode when its start_date is no more than this many days after the latest end_date " \
                               "of the earlier results, not only of the result just before. Otherwise it starts a " \
                               "new episode. A result without an end_date counts as ending on its start_date. " \
                               "The default is 0."
      category "Modify Data"
      diagram_base :temporal

      def table
        nil
      end

      # Episode strips source_vocabulary_id from its output rows (the SQL emits
      # NULL for that column), so downstream consumers can't tell which vocab
      # the data originated from. The default introspection methods on Operator
      # walk upstream and report whatever vocabularies were upstream of Episode,
      # which misrepresents what Episode actually emits. Override both methods
      # to reflect that Episode erases vocabulary metadata.
      def vocabularies
        []
      end

      def multiple_vocabularies
        false
      end

      def query(db)
        ds = unioned(db)

        partition_vars

        dt1 = ds.select(*partition_vars).select_append(
          :start_date,
          :end_date,
          Sequel[:start_date].as(:episode_start_date),
          Sequel.function(:max,
                          Sequel.function(:coalesce, :end_date,
                                          :start_date)).over(partition: partition_vars, order: %i[start_date
                                                                                                  end_date]).as(:episode_end_date)
        )

        # Get allowed episode gap
        gap_of = get_episode_gap

        # episode_end_date is the latest end so far. The lag gives it for the
        # records before this one, so a record starts a new episode when it
        # starts more than gap_of days after the end of the records before it.
        gap_check = date_adjust_add(db,
                                    Sequel.function(:lag, :episode_end_date).over(partition: partition_vars, order: %i[start_date end_date]), gap_of, "days")

        cond_gap_lt_start = (gap_check < Sequel[:start_date]) | (nil)

        dt2 = dt1.from_self.select_append(
          gap_of.as(:gap_of),
          cond_gap_lt_start.as(:step) # True if new episode else null
        )

        tmp_episode_summary = dt2.from_self.select_append(
          (Sequel.function(:count, :step).over(partition: partition_vars,
                                               order: %i[start_date
                                                         end_date]) + 1).as(:episode)
        )

        ids_plus_episode = (partition_vars + [ :episode ])

        # Get last dispensing in an episodes gap and
        last_dispensing = tmp_episode_summary.from_self.select(*ids_plus_episode)
                                             .select_append(
                                               :gap_of,
                                               rdbms.datediff(Sequel[:episode_start_date],
                                                              Sequel.function(:lag, :episode_end_date).over(
                                                                partition: partition_vars + [ :episode ], order: :start_date
                                                              )).as(:LEpisodeGap),
                                               Sequel.function(:row_number).over(partition: ids_plus_episode,
                                                                                 order: [ Sequel.desc(:start_date) ]).as(:event_number)
                                             )

        last_dispensing = last_dispensing.from_self.where(event_number: 1)

        join_hash = ids_plus_episode.map { |c| [ c, c ] }.to_h

        episode_summary = tmp_episode_summary.from_self(alias: :e).join(last_dispensing, join_hash,
                                                                        table_alias: :o)
        e = Sequel[:e]
        Sequel[:o]

        grp_cols = ids_plus_episode.map { |c| e[c] }

        episode_summary = episode_summary.select_group(*grp_cols).select_append(
          Sequel.function(:min, :episode_start_date).as(:start_date),
          Sequel.function(:max, :episode_end_date).as(:end_date)
        )

        # An episode has no criterion_id, criterion_table or criterion_domain
        # of its own, so these constants name it in every output row. They
        # were added because a NULL part made the uuid NULL. The uuid now
        # gives a NULL part as an empty string (bead conceptql-18n), but the
        # constants stay, because they are part of each episode row: the
        # expected results in test/results/gdm/episode/ show them.
        episode_summary = episode_summary.from_self.select_append(
          Sequel[0].cast_numeric.as(:criterion_id),
          Sequel.cast_string("episode").as(:criterion_table),
          Sequel.cast_string("episode").as(:criterion_domain)
        )

        episode_query_cols = partition_vars + %i[start_date end_date criterion_id criterion_table
                                                 criterion_domain]
        dm.selectify(episode_summary.from_self, { query_columns: episode_query_cols.zip(episode_query_cols).to_h,
                                                  replace: { column_family: ConceptQL::Scope::DEFAULT_COLUMN_FAMILY } })
      end

      def get_episode_gap
        # If Create treatment episodes get episode gap otherwise allow only 0 gap
        return Sequel[options[:gap_of].to_i] unless options[:gap_of].nil?

        Sequel[0]
      end

      def unioned(db)
        upstreams.map { |c| c.evaluate(db) }.inject do |uni, q|
          uni.union(q)
        end
      end

      def partition_vars
        matching_columns
      end

      ##
      # Adds `by` units of `timeframe` (days, months, etc) to the date `from`.
      # PostgreSQL and DuckDB multiply a one-unit INTERVAL; other databases
      # (Spark) use the INTERVAL n unit form.
      #

      def date_adjust_add(db, from, by, timeframe)
        if %i[postgres duckdb].include?(db.database_type)
          Sequel.cast(from + Sequel.lit("(? * INTERVAL '1' ?)", by, Sequel.lit(timeframe.sub(/s\z/, ""))), Date)
        else
          from + Sequel.lit("INTERVAL ? ?", by, Sequel.lit(timeframe))
        end
      end
    end
  end
end
