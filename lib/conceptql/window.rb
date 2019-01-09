require_relative "window/table"

module ConceptQL
  module Window
    class << self
      def from(opts)
        start_date = opts[:start_date]
        end_date = opts[:end_date]
        window_table = opts[:window_table]
        person_ids = opts[:person_ids]

        windows = []

        if start_date && end_date
          windows << lambda do |op, ds|
            start_check = op.rdbms.cast_date(start_date) <= :start_date
            end_check = Sequel.expr(:end_date) <= op.rdbms.cast_date(end_date)
            ds.from_self.where(start_check).where(end_check)
          end
        end

        if window_table
          windows << Table.new(window_table, opts[:cdb], opts[:adjust_window_start], opts[:adjust_window_end])
        end

        if person_ids
          windows << lambda do |_, ds|
            ds.where(person_id: person_ids)
          end
        end

        windows
      end
    end
  end
end
