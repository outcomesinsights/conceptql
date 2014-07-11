require 'sequel'

module ConceptQL
  module ViewMaker
    def self.make_views(db, schema = nil)
      views.each do |view, columns|
        make_view(db, schema, view, columns)
      end
    end

    def self.make_view(db, schema, view, columns)
      view_name = (view.to_s + '_with_dates')
      view_name = schema + '__' + view_name if schema
      view_name = view_name.to_sym

      table_name = view.to_s
      table_name = schema + '__' + table_name if schema
      table_name = table_name.to_sym

      additional_columns = [Sequel.expr(columns.shift).cast(:date).as(:start_date), Sequel.expr(columns.shift).cast(:date).as(:end_date)]
      unless columns.empty?
        additional_columns += columns.last.map do |column_name, column_value|
          Sequel.expr(column_value).as(column_name)
        end
      end
      query = db.from(table_name).select_all.select_append(*additional_columns)
      puts query.sql
      db.drop_view(view_name, if_exists: true)
      db.create_view(view_name, query)
    end

    def self.views
      person_date_of_birth = assemble_date(:year_of_birth, :month_of_birth, :day_of_birth)
      {
        condition_occurrence: [:condition_start_date, :condition_end_date],
        death: [:death_date, :death_date, { death_id: :person_id }],
        drug_exposure: [:drug_exposure_start_date, :drug_exposure_end_date],
        drug_cost: [nil, nil],
        payer_plan_period: [:payer_plan_period_start_date, :payer_plan_period_end_date],
        person: [person_date_of_birth, person_date_of_birth],
        procedure_occurrence: [:procedure_date, :procedure_date],
        procedure_cost: [nil, nil],
        observation: [:observation_date, :observation_date],
        visit_occurrence: [:visit_start_date, :visit_end_date]
      }
    end

    def self.assemble_date(*symbols)
      strings = symbols.map do |symbol|
        Sequel.function(:coalesce, symbol, '01').cast(:text)
      end
      strings = strings.zip(['-'] * (symbols.length - 1)).flatten.compact
      Sequel.function(:date, Sequel.join(strings))
    end
  end
end
