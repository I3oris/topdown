require "./spec_helper"

module TopDown::Spec
  AST.def_ast EmptyAST
  AST.def_ast UnaryAST, a : AST
  AST.def_ast MultiAST, a : AST, b : AST, c : AST
  AST.def_ast ValueAST, a : String, b : Int32, c : Char
  AST.def_ast DefaultValueAST, a = "a", b = 0, c = 'c'
  AST.def_ast EnumerableAST, a : Array(AST), b : Tuple(AST, AST), c : Slice(AST)
  AST.def_ast MixedAST, a : String, b : Array(AST), c = 'c', d : AST? = nil
  UnaryAST.def_ast InheritAST, a : AST, b : AST
  AST.def_ast WithBlockAST, a : AST do
    def foo
    end
  end
  AST.def_ast EnumerableMixedAST,
    a : Array(String),
    b : Array(AST|String|Nil),
    c : Tuple(AST, String),
    d : Array(String)|AST,
    e : Array(AST)|Nil

  def children_should_be(ast, *children)
    got_children = [] of typeof(ast.each_child { |c| break c })
    ast.each_child do |child|
      got_children << child
    end
    got_children.should eq children.to_a
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
      a = parse!(:ast).as(AST)
      parse!(',')
      b = parse!(:ast).as(AST)
      parse!(',')
      c = parse!(:ast).as(AST)
      parse!(',')
      d = parse!(:ast).as(AST)
      parse!(')')

      ast(EnumerableAST, [a], {b, c}, Slice.new(1) { d })
    end

    syntax :mixed, "mixed(" do
      a = parse!(/\w+/)
      parse!(',')
      b = parse!(:ast).as(AST)
      parse!(',')
      c = parse!(:ast).as(AST)
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
