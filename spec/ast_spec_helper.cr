require "./spec_helper"

module TopDown::Spec
  TopDown.def_ast EmptyAST
  TopDown.def_ast UnaryAST, a : AST
  TopDown.def_ast MultiAST, a : AST, b : AST, c : AST
  TopDown.def_ast ValueAST, a : String, b : Int32, c : Char
  TopDown.def_ast DefaultValueAST, a = "a", b = 0, c = 'c'
  TopDown.def_ast EnumerableAST, a : Array(AST), b : Tuple(AST, AST), c : Slice(AST)
  TopDown.def_ast MixedAST, a : String, b : Array(AST), c = 'c', d : AST? = nil
  TopDown.def_ast InheritAST < UnaryAST, a : AST, b : AST
  TopDown.def_ast WithBlockAST, a : AST do
    def foo
    end
  end

  class CustomAST
  end

  TopDown.def_ast WithCustomAST < CustomAST, a : String, b : Array(CustomAST), c = 'c', d : CustomAST? = nil

  def children_should_be(ast, *children)
    ast.children.should eq children.to_a
    i = 0
    ast.each_child do |child|
      child.should eq children[i]
      i += 1
    end
  end

  class ASTParser < TopDown::Parser
    def spec_parse_ast(_precedence_ = 0)
      parse!(:ast)
    end

    syntax :ast { parse(:empty | :unary | :multi | :value | :default_value | :enumerable | :mixed | :inherit) }

    syntax :empty, "empty" { ast(EmptyAST) }

    syntax :unary, "unary(" do
      a = parse!(:ast)
      parse!(')')
      ast(UnaryAST, a)
    end

    syntax :multi, "multi(" do
      a = parse!(:ast)
      parse!(',')
      b = parse!(:ast)
      parse!(',')
      c = parse!(:ast)
      parse!(')')

      ast(MultiAST, a, b, c)
    end

    syntax :value, "value(" do
      a = parse!(/\w+/)
      parse!(',')
      b = parse!(/\d+/).to_i
      parse!(',')
      skip_chars # /!\ Should not be needed
      c = parse(any)
      parse!(')')

      ast(ValueAST, a, b, c)
    end

    syntax :default_value, "default_value" do
      ast(DefaultValueAST)
    end

    syntax :enumerable, "enumerable(" do
      a = parse!(:ast).as(TopDown::AST)
      parse!(',')
      b = parse!(:ast).as(TopDown::AST)
      parse!(',')
      c = parse!(:ast).as(TopDown::AST)
      parse!(',')
      d = parse!(:ast).as(TopDown::AST)
      parse!(')')

      ast(EnumerableAST, [a], {b, c}, Slice.new(1) { d })
    end

    syntax :mixed, "mixed(" do
      a = parse!(/\w+/)
      parse!(',')
      b = parse!(:ast).as(TopDown::AST)
      parse!(',')
      c = parse!(:ast).as(TopDown::AST)
      parse!(')')

      ast(MixedAST, a, [b, c], d: nil)
    end

    syntax :inherit, "inherit(" do
      a = parse!(:ast)
      parse!(',')
      b = parse!(:ast)
      parse!(')')

      ast(InheritAST, a, b)
    end

    skip { parse(' ' | '\n') }
  end

  class_getter ast_parser = ASTParser.new("")
end
