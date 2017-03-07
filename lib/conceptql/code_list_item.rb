CodeListItem = Struct.new(:vocabulary, :code, :description) do
  def to_s
    "#{vocabulary} #{code}: #{description}"
  end
end

