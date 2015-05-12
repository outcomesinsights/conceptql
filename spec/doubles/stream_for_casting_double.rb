class StreamForCastingDouble < ConceptQL::Operators::Operator
  def query(db)
    db.from(:table)
  end

  def types=(types)
    @types = types
  end
end
