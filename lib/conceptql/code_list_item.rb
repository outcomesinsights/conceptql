CodeListItem = Struct.new(:vocabulary, :code, :description) do
  def to_s
    output = "#{vocabulary} #{code}"
    output << ": #{description}" if description
    output
  end
end

