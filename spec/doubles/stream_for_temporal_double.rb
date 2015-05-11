class StreamForTemporalDouble < ConceptQL::Operators::Node
  def query(db)
    db.from(:table)
  end
end

