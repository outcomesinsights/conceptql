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
          windows << lambda do |op, ds, opts = {}|
            return ds if opts[:timeless]
            start_check = op.rdbms.cast_date(start_date) <= :start_date
            end_check = Sequel.expr(:end_date) <= op.rdbms.cast_date(end_date)
            ds.where(start_check).where(end_check).from_self
          end
        end

        if window_table
          windows << Table.new(window_table, opts[:cdb], opts[:adjust_window_start], opts[:adjust_window_end])
        end

        if person_ids
          windows << lambda do |_, ds, opts = {}|
            ds.where(person_id: person_ids)
          end
        end

        windows
      end
    end
  end
end
