require 'conceptql/operators/operator'
class QueryDouble < ConceptQL::Operators::Operator
  def initialize(num, type = :visit_occurrence)
    @num = num
    @type = type
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
