module ConceptQL
  class NodeSorter
    def initialize(ops)
      @original_ops = ops.dup
      @all_ops = ops.dup
      @marked_ops = []
      @temp_marked_ops = []
    end

    def sort_it_out
      @list = []
      until @all_ops.empty?
        @temp_marked_ops = []
        visit(@all_ops.shift)
      end
      @list
    end

    def list
      @list ||= sort_it_out
    end

    def visit(op)
      return if @marked_ops.include?(op)
      return :invalid if @temp_marked_ops.include?(op)
      @temp_marked_ops << op
      nodes = [downstream(op)]
      nodes << op.original if op.respond_to?(:original)
      nodes.compact.each do |other_op|
        visit(other_op)
      end
      @marked_ops << op
      @temp_marked_ops.delete(op)
      @list.unshift(op)
      return :ok
    end

    def downstream(op)
      @original_ops.each do |orig_op|
        return orig_op if orig_op.all_upstreams.include?(op)
      end
      return nil
    end
  end
end
