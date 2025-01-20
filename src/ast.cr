require "./char_reader"

module TopDown
  # TODO docs
  abstract class AST
    # TODO docs
    getter location = Location.new(0, 0, 0, 0)
    # TODO docs
    getter end_location = Location.new(0, 0, 0, 0)

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
    # Override this method to indicate the children of this AST node
    def each_child(&)
      {% for ivar in @type.instance_vars %}
        if TopDown.ast_child?(@{{ivar}})
          if ({{ivar}} = @{{ivar}}).is_a? Enumerable
            {{ivar}}.each { |child| yield child }
          else
            yield @{{ivar}}
          end
        end
      {% end %}
    end

    # TODO docs
    def to_s(io, indent = 0)
      self.to_s_without_children(io)

      each_child do |child|
        io << '\n'
        (indent + 1).times { io << "  " }
        if child.is_a? AST
          child.to_s(io, indent + 1)
        else
          child.inspect(io)
        end
      end
    end

    # TODO docs
    def to_s_without_children(io)
      {% begin %}
        io << {{@type.name(generic_args: false).split("::")[-1]}}

        values = [] of String
        {% for ivar in @type.instance_vars %}
          {% unless ivar.type <= Location %}
            unless TopDown.ast_child?(@{{ivar}})
              values << "{{ivar.name}}: #{ @{{ivar}}.inspect }"
            end
          {% end %}
        {% end %}

        unless values.empty?
          io << '('
          values.join(io, ", ")
          io << ')'
        end
      {% end %}
    end

    # TODO docs
    macro def_ast(class_name, *properties)
      class {{class_name}} < {{@type}}
        getter {{properties.splat}}

        def initialize({{properties.map { |p| "@#{p.id}".id }.splat}})
        end

        {{ yield }}
      end
    end
  end

  # :nodoc:
  protected def self.ast_child?(obj : Enumerable(T)) forall T
    {{ T.union_types.any? &.<= AST }}
  end

  # :nodoc:
  protected def self.ast_child?(obj : T) forall T
    {{ T.union_types.any? &.<= AST }}
  end

  abstract class Parser < CharReader
    # TODO docs
    macro ast(ast_class, *args, at = nil, **options)
      {{ast_class}}.new({{args.splat ", "}} {{options.double_splat(", ")}}).at({{at || "begin_location()..self.location".id}})
    end
  end
end
