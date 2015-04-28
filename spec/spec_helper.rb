require 'sequel'

class Minitest::SharedExamples < Module
  include Minitest::Spec::DSL

  def self.find(name)
    @shared_examples ||= {}
    @shared_examples[name]
  end

  def self.register(name, &block)
    @shared_examples ||= {}
    @shared_examples[name] = block
  end
end

def shared_examples_for(name, &block)
  Minitest::SharedExamples.register(name, &block)
end

shared_examples_for(:evaluator) do |subject|
  subject.must_respond_to(:evaluate)
  subject.must_respond_to(:query)
  subject.must_respond_to(:types)
end

shared_examples_for(:source_vocabulary_node) do |subject|
  subject.must_behave_like(:evaluator)
  subject.must_respond_to(:table)
  subject.must_respond_to(:concept_column)
  subject.must_respond_to(:source_column)
  subject.must_respond_to(:vocabulary_id)
end

shared_examples_for(:standard_vocabulary_node) do |subject|
  subject.must_behave_like(:evaluator)
  subject.must_respond_to(:table)
  subject.must_respond_to(:concept_column)
  subject.must_respond_to(:vocabulary_id)
end

shared_examples_for(:node) do |subject|
  subject.must_respond_to(:values)
  subject.must_respond_to(:arguments)
  subject.must_respond_to(:upstreams)
end

shared_examples_for(:temporal_node) do |subject|
  subject.must_behave_like(:evaluator)
  subject.must_respond_to(:where_clause)
end

shared_examples_for(:casting_node) do |subject|
  subject.must_behave_like(:evaluator)
  subject.must_respond_to(:my_type)
  subject.must_respond_to(:i_point_at)
  subject.must_respond_to(:these_point_at_me)
end

module Minitest::Assertions
  def assert_behaves_like(subject, name, msg = nil)
    Minitest::SharedExamples.find(name).call(subject)
  end
end

module Minitest::Expectations
  infect_an_assertion :assert_behaves_like, :must_behave_like, :reverse
end

def require_double(double_name)
  p = Pathname.new('.')
  p = p + 'spec' + 'doubles' + (double_name + '_double')
  require(p.expand_path)
end

def stub_const(klass, const, replace, &block)
  klass.send(:const_set, const, replace)
  if block_given?
    yield
    remove_stubbed_const(klass, const)
  end
end

def remove_stubbed_const(klass, const)
  klass.send(:remove_const, const)
end
