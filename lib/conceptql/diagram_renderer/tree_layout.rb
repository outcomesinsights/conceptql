# frozen_string_literal: true

module ConceptQL
  module DiagramRenderer
    # A port of d3-hierarchy 3.1.2 (the version frontend/package-lock.json
    # resolves): hierarchy() and tree(), the tidy tree layout of Buchheim, Jünger
    # and Leipert (the linear-time version of Reingold-Tilford), as
    # d3-hierarchy's src/tree.js implements it. Only the nodeSize mode is ported,
    # because geometry.js uses only that mode.
    #
    # The arithmetic is the same as the JavaScript, in the same order and in
    # Float (IEEE double, as JavaScript numbers), so the x values are the same
    # to the last bit.
    #
    #   root = TreeLayout.hierarchy(data) { |d| d["children"] }
    #   TreeLayout.new(node_size: [200, 140], separation: ->(_a, _b) { 1 }).call(root)
    #   root.descendants.map { [it.x, it.y] }
    class TreeLayout
      # eachBefore and eachAfter, for Node and TreeNode (in tree.js, TreeNode
      # inherits them from Node). Both need only `children`.
      module Traversal
        # Pre-order, children left to right (node.eachBefore).
        def each_before
          nodes = [ self ]
          while (node = nodes.pop)
            yield node
            node.children&.reverse_each { nodes.push(_1) }
          end
          self
        end

        # Post-order, children left to right (node.eachAfter).
        def each_after
          nodes = [ self ]
          after = []
          while (node = nodes.pop)
            after.push(node)
            node.children&.each { nodes.push(_1) }
          end
          yield after.pop until after.empty?
          self
        end
      end

      # A node of the hierarchy (d3-hierarchy Node). `children` is nil for a
      # leaf, as in d3: an empty child list makes no children.
      class Node
        include Traversal

        attr_accessor :data, :depth, :height, :parent, :children, :x, :y, :data_index

        def initialize(data)
          @data = data
          @depth = 0
          @height = 0
          @parent = nil
          @children = nil
        end

        # Breadth-first, children left to right (node[Symbol.iterator] and
        # node.descendants()).
        def descendants
          found = []
          level = [ self ]
          until level.empty?
            found.concat(level)
            level = level.flat_map { _1.children || [] }
          end
          found
        end

        # Every parent-child link, in descendants order (node.links()).
        def links
          descendants.drop(1).map { Link.new(_1.parent, _1) }
        end
      end

      Link = Struct.new(:source, :target)

      # d3.hierarchy(data, children): the block returns a datum's children.
      def self.hierarchy(data, &children)
        root = Node.new(data)
        nodes = [ root ]
        while (node = nodes.pop)
          childs = children.call(node.data)
          next if childs.nil? || childs.empty?

          node.children = childs.map { Node.new(_1) }
          node.children.reverse_each do |child|
            nodes.push(child)
            child.parent = node
            child.depth = node.depth + 1
          end
        end
        root.each_before { compute_height(_1) }
      end

      # computeHeight in hierarchy/index.js.
      def self.compute_height(node)
        height = 0
        loop do
          node.height = height
          node = node.parent
          height += 1
          break unless node && node.height < height
        end
      end
      private_class_method :compute_height

      # TreeNode in tree.js: the layout's working state for one node.
      #   z prelim, m mod, c change, s shift, t thread, a ancestor,
      #   ancestor_default A, i number among its siblings.
      class TreeNode
        include Traversal

        attr_accessor :node, :parent, :children, :ancestor_default, :a, :z, :m, :c, :s, :t, :i

        def initialize(node, i)
          @node = node
          @parent = nil
          @children = nil
          @ancestor_default = nil
          @a = self
          @z = 0.0
          @m = 0.0
          @c = 0.0
          @s = 0.0
          @t = nil
          @i = i
        end
      end

      def initialize(node_size:, separation:)
        @dx = Float(node_size[0])
        @dy = Float(node_size[1])
        @separation = separation
      end

      # tree(root): sets x and y on every node of the hierarchy and returns it.
      def call(root)
        t = tree_root(root)

        t.each_after { first_walk(_1) }
        t.parent.m = -t.z
        t.each_before { second_walk(_1) }

        root.each_before { size_node(_1) }
        root
      end

      private

      # treeRoot in tree.js.
      def tree_root(root)
        tree = TreeNode.new(root, 0)
        nodes = [ tree ]
        while (node = nodes.pop)
          children = node.node.children
          next unless children

          node.children = Array.new(children.length)
          (children.length - 1).downto(0) do |i|
            child = node.children[i] = TreeNode.new(children[i], i)
            nodes.push(child)
            child.parent = node
          end
        end

        tree.parent = TreeNode.new(nil, 0)
        tree.parent.children = [ tree ]
        tree
      end

      # The separation function, called with hierarchy nodes; Float like a
      # JavaScript number.
      def separation(a, b) = Float(@separation.call(a, b))

      # nextLeft in tree.js.
      def next_left(v) = v.children ? v.children[0] : v.t

      # nextRight in tree.js.
      def next_right(v) = v.children ? v.children[-1] : v.t

      # moveSubtree in tree.js.
      def move_subtree(wm, wp, shift)
        change = shift / (wp.i - wm.i)
        wp.c -= change
        wp.s += shift
        wm.c += change
        wp.z += shift
        wp.m += shift
      end

      # executeShifts in tree.js.
      def execute_shifts(v)
        shift = 0.0
        change = 0.0
        v.children.reverse_each do |w|
          w.z += shift
          w.m += shift
          change += w.c
          shift += w.s + change
        end
      end

      # nextAncestor in tree.js.
      def next_ancestor(vim, v, ancestor)
        vim.a.parent.equal?(v.parent) ? vim.a : ancestor
      end

      # firstWalk in tree.js.
      def first_walk(v)
        children = v.children
        siblings = v.parent.children
        w = v.i.zero? ? nil : siblings[v.i - 1]
        if children
          execute_shifts(v)
          midpoint = (children[0].z + children[-1].z) / 2
          if w
            v.z = w.z + separation(v.node, w.node)
            v.m = v.z - midpoint
          else
            v.z = midpoint
          end
        elsif w
          v.z = w.z + separation(v.node, w.node)
        end
        v.parent.ancestor_default = apportion(v, w, v.parent.ancestor_default || siblings[0])
      end

      # secondWalk in tree.js.
      def second_walk(v)
        v.node.x = v.z + v.parent.m
        v.m += v.parent.m
      end

      # apportion in tree.js.
      def apportion(v, w, ancestor)
        return ancestor unless w

        vip = v
        vop = v
        vim = w
        vom = vip.parent.children[0]
        sip = vip.m
        sop = vop.m
        sim = vim.m
        som = vom.m
        loop do
          vim = next_right(vim)
          vip = next_left(vip)
          break unless vim && vip

          vom = next_left(vom)
          vop = next_right(vop)
          vop.a = v
          shift = vim.z + sim - vip.z - sip + separation(vim.node, vip.node)
          if shift > 0
            move_subtree(next_ancestor(vim, v, ancestor), v, shift)
            sip += shift
            sop += shift
          end
          sim += vim.m
          sip += vip.m
          som += vom.m
          sop += vop.m
        end
        if vim && !next_right(vop)
          vop.t = vim
          vop.m += sim - sop
        end
        if vip && !next_left(vom)
          vom.t = vip
          vom.m += sip - som
          ancestor = v
        end
        ancestor
      end

      # sizeNode in tree.js.
      def size_node(node)
        node.x *= @dx
        node.y = node.depth * @dy
      end
    end
  end
end
