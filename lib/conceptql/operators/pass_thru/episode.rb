require_relative "base"

module ConceptQL
  module Operators
    module PassThru
      class Episode < Base
        include ConceptQL::Behaviors::Selectable
        register __FILE__

        desc <<-EOF
Groups all incoming results into episodes by person allowing for there to be a gap, defined by "Gap Of", between the end date of an event and the start date of the next one to be considered the same episode.
        EOF
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
            Sequel[gap_of].as(:gap_of),
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
              (rdbms.days_between(Sequel[:episode_start_date], Sequel.function(:lag, :episode_end_date).over(partition: partition_vars + [:episode], order: :start_date))).as(:LEpisodeGap),
              Sequel.function(:row_number).over(partition: ids_plus_episode, order: [Sequel.desc(:start_date)]).as(:event_number)
          )

          last_dispensing = last_dispensing.from_self.where(event_number: 1)

          join_hash = ids_plus_episode.map{|c| [c,c]}.to_h

          episode_summary = tmp_episode_summary.from_self(alias: :e).join(last_dispensing, join_hash,
                                                                          table_alias: :o)
          e = Sequel[:e]
          o = Sequel[:o]

          grp_cols = ids_plus_episode.map{|c| e[c]}

          episode_summary = make_selectable(
            episode_summary
              .select_group(*grp_cols)
              .select_append(
                Sequel.function(:min, :episode_start_date).as(:start_date),
                Sequel.function(:max, :episode_end_date).as(:end_date),
                Sequel[0].cast_numeric.as(:criterion_id),
                Sequel.cast_string("episode").as(:criterion_table),
                Sequel.cast_string("episode").as(:criterion_domain),
                cast_column(:source_value).as(:source_value),
                cast_column(:source_vocabulary_id).as(:source_vocabulary_id)
              )
              .from_self
          )

          # Episodes streams return null for criterion_id,table, and domain which messes up uuid generation so we had to add constants to these values
          episode_summary = episode_summary
            .auto_column(:window_id, :window_id)
            .auto_column_default(null_columns)

          episode_summary
        end

        def get_episode_gap
          # If Create treatment episodes get episode gap otherwise allow only 0 gap
          return options[:gap_of].to_i
          return Sequel[options[:gap_of].to_i].cast_numeric
        end

        def unioned(db)
          upstreams.map { |c| c.evaluate(db) }.inject do |uni, q|
            uni.union(q)
          end
        end

        def partition_vars
          return matching_columns
        end

        def date_adjust_add(db, from, by, timeframe)
          DateAdjuster.new(self, "#{by}#{timeframe.chars.first}").adjust(from)
        end
      end
    end
  end
end
