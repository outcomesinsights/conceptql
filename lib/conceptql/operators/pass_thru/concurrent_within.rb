require_relative "base"

module ConceptQL
  module Operators
    class ConcurrentWithin < Base
      register __FILE__

      desc 'Filters each upstream to only include rows where there are matching entries in each of the other upstreams.'
      option :start, type: :string
      option :end, type: :string
      allows_many_upstreams
      validate_at_least_one_upstream
      validate_no_arguments
      validate_option DateAdjuster::VALID_INPUT, :start, :end
      category "Combine Streams"
      basic_type :set

      def query(db)
        datasets = upstreams.map do |stream|
          stream.evaluate(db)
        end

        return datasets.first.from_self if datasets.length == 1

        adjusted_start_date = DateAdjuster.new(self, options[:start]).adjust(Sequel[:l][:start_date], true)
        adjusted_end_date = DateAdjuster.new(self, options[:end]).adjust(Sequel[:l][:end_date])

        datasets = datasets.map do |ds|
          matching = ds.from_self(:alias=>:l)

          (datasets - [ds]).each do |other|
            other = other
              .from_self(:alias=>:r)
              .where(adjusted_start_date <= Sequel[:r][:start_date])
              .where(adjusted_end_date >= Sequel[:r][:end_date])
              .select(*matching_columns)

            matching = matching.where(other.where(matching_columns.map{|x| [Sequel.qualify(:l, x), Sequel.qualify(:r, x)]}).exists)
          end

          matching
        end

        ds, *rest = datasets
        rest.each do |other|
          ds = ds.union(other, :from_self=>nil)
        end

        ds.from_self
      end
    end
  end
end


