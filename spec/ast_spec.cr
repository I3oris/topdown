require "./ast_spec_helper.cr"

empty_ast = TopDown::Spec::EmptyAST.new

describe TopDown::AST do
  it "gives children" do
    a = TopDown::Spec::UnaryAST.new(a: empty_ast)
    b = TopDown::Spec::UnaryAST.new(a: empty_ast)
    c = TopDown::Spec::UnaryAST.new(a: empty_ast)
    d = TopDown::Spec::UnaryAST.new(a: empty_ast)

    ast = TopDown::Spec::EmptyAST.new
    TopDown::Spec.children_should_be(ast, *Tuple.new)

    ast = TopDown::Spec::UnaryAST.new(a: a)
    TopDown::Spec.children_should_be(ast, a)

    ast = TopDown::Spec::MultiAST.new a: a, b: b, c: c
    TopDown::Spec.children_should_be(ast, a, b, c)

    ast = TopDown::Spec::ValueAST.new a: "1", b: 9, c: '4'
    TopDown::Spec.children_should_be(ast, *Tuple.new)

    ast = TopDown::Spec::DefaultValueAST.new b: 42
    TopDown::Spec.children_should_be(ast, *Tuple.new)

    ast = TopDown::Spec::EnumerableAST.new a: [a] of TopDown::AST, b: {b, c}, c: Slice.new(1) { d.as(TopDown::AST) }
    TopDown::Spec.children_should_be(ast, a, b, c, d)

    ast = TopDown::Spec::MixedAST.new a: "foo", b: [a, b] of TopDown::AST
    TopDown::Spec.children_should_be(ast, a, b, nil)

    ast = TopDown::Spec::MixedAST.new a: "foo", b: [a, b] of TopDown::AST, d: c
    TopDown::Spec.children_should_be(ast, a, b, c)

    ast = TopDown::Spec::InheritAST.new a: a, b: b
    TopDown::Spec.children_should_be(ast, a, b)

    ast = TopDown::Spec::WithBlockAST.new(a: a)
    TopDown::Spec.children_should_be(ast, a)

    ast = TopDown::Spec::EnumerableMixedAST.new a: ["1"], b: ["2", b.as(TopDown::AST), nil], c: {c, "3"}, d: d, e: [a] of TopDown::AST
    TopDown::Spec.children_should_be(ast, "2", b, nil, c, "3", d, a)
  end

  it "creates ast" do
    ast_parser = TopDown::Spec.ast_parser
    ast_parser.source = <<-SOURCE
      multi(
        unary(empty),
        value(foo, 0, c),
        enumerable(
          default_value,
          mixed(bar, empty, empty),
          inherit(empty, empty),
          empty
        )
      )
      SOURCE
    ast = ast_parser.spec_parse_ast
    ast.should be_a TopDown::Spec::MultiAST
    if (m = ast).is_a?(TopDown::Spec::MultiAST)
      m.a.should be_a TopDown::Spec::UnaryAST
      if (u = m.a).is_a?(TopDown::Spec::UnaryAST)
        u.a.should be_a TopDown::Spec::EmptyAST
      end
      m.b.should be_a TopDown::Spec::ValueAST
      if (v = m.b).is_a?(TopDown::Spec::ValueAST)
        v.a.should eq "foo"
        v.b.should eq 0
        v.c.should eq 'c'
      end
      m.c.should be_a TopDown::Spec::EnumerableAST
      if (e = m.c).is_a?(TopDown::Spec::EnumerableAST)
        e.a.size.should eq 1
        e.a[0].should be_a TopDown::Spec::DefaultValueAST
        if (dv = e.a[0]).is_a?(TopDown::Spec::DefaultValueAST)
          dv.a.should eq "a"
          dv.b.should eq 0
          dv.c.should eq 'c'
        end
        e.b[0].should be_a TopDown::Spec::MixedAST
        if (mx = e.b[0]).is_a?(TopDown::Spec::MixedAST)
          mx.a.should eq "bar"
          mx.b[0].should be_a TopDown::Spec::EmptyAST
          mx.b[1].should be_a TopDown::Spec::EmptyAST
          mx.c.should eq 'c'
          mx.d.should be_nil
        end
        e.b[1].should be_a TopDown::Spec::InheritAST
        if (i = e.b[1]).is_a?(TopDown::Spec::InheritAST)
          i.a.should be_a TopDown::Spec::EmptyAST
          i.b.should be_a TopDown::Spec::EmptyAST
        end
        e.c.size.should eq 1
        e.c[0].should be_a TopDown::Spec::EmptyAST
      end
    end
  end

  it "set location while creating ast" do
    ast_parser = TopDown::Spec.ast_parser
    ast_parser.source = <<-SOURCE
      multi(
        unary(empty),
        value(foo, 0, c),
        enumerable(
          default_value,
          mixed(bar, empty, empty),
          inherit(empty, empty),
          empty
        )
      )
      SOURCE
    ast = ast_parser.spec_parse_ast

    m = ast.as(TopDown::Spec::MultiAST)
    m.location.should eq TopDown::Location.new(0, 0, 0, 0)
    m.end_location.should eq TopDown::Location.new(148, line_number: 9, line_pos: 1, token_pos: 0)

    e = m.c.as(TopDown::Spec::EnumerableAST)
    e.location.should eq TopDown::Location.new(45, line_number: 3, line_pos: 2, token_pos: 0)
    e.end_location.should eq TopDown::Location.new(146, line_number: 8, line_pos: 3, token_pos: 0)

    mx = e.b[0].as(TopDown::Spec::MixedAST)
    mx.location.should eq TopDown::Location.new(80, line_number: 5, line_pos: 4, token_pos: 0)
    mx.end_location.should eq TopDown::Location.new(104, line_number: 5, line_pos: 28, token_pos: 0)
  end

  it "to_s" do
    ast_parser = TopDown::Spec.ast_parser
    ast_parser.source = <<-SOURCE
      multi(
        unary(empty),
        value(foo, 0, c),
        enumerable(
          default_value,
          mixed(bar, empty, empty),
          inherit(empty, empty),
          empty
        )
      )
      SOURCE
    ast = ast_parser.spec_parse_ast
    ast.to_s.should eq <<-TO_S
      MultiAST
        UnaryAST
          EmptyAST
        ValueAST(a: "foo", b: 0, c: 'c')
        EnumerableAST
          DefaultValueAST(a: "a", b: 0, c: 'c')
          MixedAST(a: "bar", c: 'c')
            EmptyAST
            EmptyAST
            nil
          InheritAST
            EmptyAST
            EmptyAST
          EmptyAST
      TO_S
  end
end
