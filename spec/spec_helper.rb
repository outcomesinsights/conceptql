require 'sequel'

shared_examples_for(:evaluator) do
  let(:evaluator) { described_class.new }
  it "should respond to evaluate" do
    expect(evaluator.respond_to?(:evaluate)).to be true
  end

  it "should respond to query" do
    expect(evaluator.respond_to?(:query)).to be true
  end

  it "shoudl respond to types" do
    expect(evaluator.respond_to?(:types)).to be true
  end
end

shared_examples_for(:source_vocabulary_operator) do
  let(:source_vocabulary_operator) { described_class.new }
  it_behaves_like :evaluator

  it "should respond to #table" do
    expect(source_vocabulary_operator.respond_to?(:table)).to be true
  end

  it "should respond to #concept_column" do
    expect(source_vocabulary_operator.respond_to?(:concept_column)).to be true
  end

  it "should respond to #source_column" do
    expect(source_vocabulary_operator.respond_to?(:source_column)).to be true
  end

  it "should respond to #vocabulary_id" do
    expect(source_vocabulary_operator.respond_to?(:vocabulary_id)).to be true
  end
end

shared_examples_for(:standard_vocabulary_operator) do
  let(:standard_vocabulary_operator) { described_class.new }

  it_behaves_like :evaluator

  it "should respond to #table" do
    expect(standard_vocabulary_operator.respond_to?(:table)).to be true
  end

  it "should respond to #concept_column" do
    expect(standard_vocabulary_operator.respond_to?(:concept_column)).to be true
  end

  it "should respond to #vocabulary_id" do
    expect(standard_vocabulary_operator.respond_to?(:vocabulary_id)).to be true
  end
end

shared_examples_for(:operator) do
  let(:operator) { described_class.new }

  it "should respond to #values" do
    expect(operator.respond_to?(:values)).to be true
  end

  it "should respond to #arguments" do
    expect(operator.respond_to?(:arguments)).to be true
  end

  it "should respond to #upstreams" do
    expect(operator.respond_to?(:upstreams)).to be true
  end
end

shared_examples_for(:temporal_operator) do
  let(:temporal_operator) { described_class.new }

  it "should respond to #where_clause" do
    expect(temporal_operator.respond_to?(:where_clause)).to be true
  end
end

shared_examples_for(:casting_operator) do
  let(:casting_operator) { described_class.new }
  it_behaves_like(:evaluator)

  it "should respond to #my_type" do
    expect(casting_operator.respond_to?(:my_type)).to be true
  end

  it "should respond to #i_point_at" do
    expect(casting_operator.respond_to?(:i_point_at)).to be true
  end

  it "should respond to #these_point_at_me" do
    expect(casting_operator.respond_to?(:these_point_at_me)).to be true
  end
end

def require_double(double_name)
  p = File.join('.', 'spec', 'doubles', double_name + '_double')
  require(File.expand_path(p))
end
