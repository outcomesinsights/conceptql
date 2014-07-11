class StreamForCastingDouble < ConceptQL::Nodes::Node
  def query(db)
    db.from(:table)
  end

  def types=(types)
    @types = types
  end
end
