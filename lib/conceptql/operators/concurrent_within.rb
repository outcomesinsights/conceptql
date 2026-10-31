# frozen_string_literal: true

require_relative "operator"
require_relative "../date_adjuster"

module ConceptQL
  module Operators
    class ConcurrentWithin < Operator
      register __FILE__

      def events_per_patient
        upstreams.all? { |u| u.events_per_patient == :single } ? :single : :multiple
      end

      def multiple_vocabularies
        return true if upstreams.any?(&:multiple_vocabularies)

        vocabularies.length > 1
      end

      desc "Passes along each record of an upstream stream when every other upstream stream " \
           "has a record of the same person inside the record's date range. " \
           "The start option sets how far before the start_date that date range begins, " \
           "and the end option sets how far after the end_date it ends. " \
           "With only one upstream stream, the operator passes along all of its records."
      option :start, type: :string
      option :end, type: :string
      allows_many_upstreams
      validate_at_least_one_upstream
      validate_no_arguments
      validate_option DateAdjuster::VALID_INPUT, :start, :end
      category "Combine Streams"
      basic_type :set
      default_query_columns

      def query(db)
        datasets = upstreams.map do |stream|
          stream.evaluate(db)
        end

        return datasets.first.from_self if datasets.length == 1

        adjusted_start_date = DateAdjuster.new(self, options[:start]).adjust(Sequel[:l][:start_date], true)
        adjusted_end_date = DateAdjuster.new(self, options[:end]).adjust(Sequel[:l][:end_date])

        datasets = datasets.map do |ds|
          matching = ds.from_self(alias: :l)

          (datasets - [ ds ]).each do |other|
            other = other
                    .from_self(alias: :r)
                    .where(adjusted_start_date <= Sequel[:r][:start_date])
                    .where(adjusted_end_date >= Sequel[:r][:end_date])
                    .select(*matching_columns)

            matching = matching.where(other.where(matching_columns.map do |x|
              [ Sequel.qualify(:l, x), Sequel.qualify(:r, x) ]
            end).exists)
          end

          matching
        end

        ds, *rest = datasets
        rest.each do |other|
          ds = ds.union(other, from_self: nil)
        end

        ds.from_self
      end
    end
  end
end
