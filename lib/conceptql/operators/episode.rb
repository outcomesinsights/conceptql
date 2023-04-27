require_relative 'pass_thru'

module ConceptQL
  module Operators
    class Episode < PassThru
      register __FILE__

      desc "Groups each person's records into episodes, allowing for a gap between the end_date of one record and the start_date of the next."

      allows_one_upstream
      validate_one_upstream
      option :gap_of, type: :integer, instructions: 'Allowed gap in days between end date of one event and start date of the next to consider them the same episode'
      category "Modify Data"
      basic_type :temporal

      def table
        nil
      end

      def query(db)
        ds = unioned(db)

        ids_plus_episode = (partition_vars + [:episode])

        dt1 = ds.select(*partition_vars).select_append(
            :start_date,
            :end_date,
            Sequel[:start_date].as(:episode_start_date),
            Sequel.function(:max,
              Sequel.function(:coalesce, :end_date, :start_date)).over(partition: partition_vars, order: [:start_date, :end_date]).as(:episode_end_date)
          )

        # Get allowed episode gap
        gap_of = get_episode_gap

        gap_check = date_adjust_add( db, Sequel.function(:lag, :episode_end_date).over(partition: partition_vars, order: [:start_date, :end_date]), gap_of, "days")

        cond_gap_lt_start = (gap_check < Sequel[:episode_end_date]) | (nil)

        dt2 = dt1.from_self.select_append(
          gap_of.as(:gap_of),
          cond_gap_lt_start.as(:step) # True if new episode else null
        )

        tmp_episode_summary = dt2.from_self.select_append(
          (Sequel.function(:count,:step).over(partition: partition_vars, order: [:start_date, :end_date]) + 1).as(:episode)
        )

        ids_plus_episode = (partition_vars + [:episode])

        # Get last dispensing in an episodes gap and
        last_dispensing = tmp_episode_summary.from_self.select(*ids_plus_episode).
          select_append(
            :gap_of,
            datediff(db, Sequel[:episode_start_date], Sequel.function(:lag, :episode_end_date).over(partition: partition_vars + [:episode], order: :start_date)).as(:LEpisodeGap),
            Sequel.function(:row_number).over(partition: ids_plus_episode, order: [Sequel.desc(:start_date)]).as(:event_number)
          )

        last_dispensing = last_dispensing.from_self.where(event_number: 1)

        join_hash = ids_plus_episode.map{|c| [c,c]}.to_h

        episode_summary = tmp_episode_summary.from_self(alias: :e).join(last_dispensing, join_hash,
                                                    table_alias: :o)
       e = Sequel[:e]
       o = Sequel[:o]

       grp_cols = ids_plus_episode.map{|c| e[c]}

       episode_summary = episode_summary.select_group(*grp_cols).select_append(
            Sequel.function(:min, :episode_start_date).as(:start_date),
            Sequel.function(:max, :episode_end_date).as(:end_date)
          )

       # Episodes streams return null for criterion_id,table, and domain which messes up uuid generation so we had to add constants to these values
       episode_summary = episode_summary.from_self.select_append(
          Sequel[0].cast_numeric.as(:criterion_id),
          Sequel.cast_string("episode").as(:criterion_table),
          Sequel.cast_string("episode").as(:criterion_domain)
        )

        episode_query_cols = partition_vars + [:start_date, :end_date, :criterion_id, :criterion_table, :criterion_domain]
        return dm.selectify(episode_summary.from_self, {query_columns: episode_query_cols.zip(episode_query_cols).to_h})
      end

      def get_episode_gap
        # If Create treatment episodes get episode gap otherwise allow only 0 gap
        return Sequel[options[:gap_of]].cast_numeric unless options[:gap_of].nil?
        return Sequel[0].cast_numeric
      end

      def unioned(db)
        upstreams.map { |c| c.evaluate(db) }.inject do |uni, q|
          uni.union(q)
        end
      end

      def partition_vars
        return matching_columns
      end

      ##
      # Method to generate Impala/PostgreSQL specific sequel to add a particular timeframe (days, months, etc) to a date
      #

      def date_adjust_add(db, from, by, timeframe)
        if db.database_type == :postgres
          Sequel.cast(from + Sequel.lit("(? * INTERVAL '1' ?)", by, Sequel.lit(timeframe.sub(/s\z/, ''))), Date)
        else
          from + Sequel.lit("INTERVAL ? ?", by, Sequel.lit(timeframe))
        end
      end

      ##
      # Method to generate Impala/PostgreSQL specific sequel to subtract two dates
      #

      def datediff(db, from, to)
        if db.database_type == :postgres
          Sequel.extract(:days, Sequel.cast(from, Time) - Sequel.cast(to, Time))
        else
          Sequel.function(:datediff, from, to)
        end
      end
    end
  end
end

