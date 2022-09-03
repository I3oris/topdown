module TopDown
  # TODO docs
  abstract class AST
    # TODO docs
    getter location = Location.new(0, 0, 0)
    # TODO docs
    getter end_location = Location.new(0, 0, 0)

    # TODO docs
    def at(@location : Location, @end_location : Location = location)
      self
    end

    # TODO docs
    def at(location : Range(Location, Location))
      @location, @end_location = location.begin, location.end
      self
    end

    # TODO docs
    def children
      children = [] of AST
      each_child do |c|
        children << c
      end
      children
    end

    # TODO docs
    def each_child(& : AST ->)
      {% for ivar in @type.instance_vars %}
        {% if ivar.type <= AST %}
          yield @{{ivar}}
        {% elsif ivar.type <= Enumerable %}
          @{{ivar}}.each { |c| yield c if c.is_a? AST }
        {% else %}
          if ({{ivar}} = @{{ivar}}).is_a? AST
            yield {{ivar}}
          end
        {% end %}
      {% end %}
    end
  end

  # TODO docs
  macro def_ast(class_name, *properties)
    {% begin %}
      {% if class_name.is_a?(Call) && class_name.name == "<" %}
        class {{class_name}}
      {% else %}
        class {{class_name}} < AST
      {% end %}
        getter {{*properties}}

        def initialize({{*properties.map { |p| "@#{p.id}".id }}})
        end

        {{ yield }}
      end
    {% end %}
  end

  abstract class Parser < CharReader
    # TODO docs
    macro ast(ast_class, *args, at = nil, **options)
      {{ast_class}}.new({{args.splat ", "}} {{options.double_splat(", ")}}).at({{at || "begin_location()..self.location".id}})
    end
  end
end
