class StreamForCastingDouble < ConceptQL::Operators::Node
  def query(db)
    db.from(:table)
  end

  def types=(types)
    @types = types
  end
end
