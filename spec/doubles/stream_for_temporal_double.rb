class StreamForTemporalDouble < ConceptQL::Nodes::Node
  def query(db)
    db.from(:table)
  end
end

