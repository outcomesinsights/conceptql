require 'conceptql/operators/operator'
class QueryDouble < ConceptQL::Operators::Operator
  def initialize(*args)
    super
    @num = arguments.first
    @type = arguments[1] || :visit_occurrence
  end

  def types
    [@type]
  end

  def evaluate(db)
    query(db)
  end

  def query(db)
    db["table#{@num}".to_sym]
  end
end
