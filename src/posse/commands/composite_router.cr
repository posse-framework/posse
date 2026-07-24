module Posse
  module Commands
    module CompositeRouter
      macro included
        Log = ::Log.for(self)

        macro finished
          {% behaviors = [] of ASTNode %}

          {% for method in @type.methods %}
            {% if ann = method.annotation(Posse::Commands::Behavior) %}
              {% behaviors << ann[0] %}
            {% end %}
          {% end %}

          def self.route_to_child(child, command, **kwargs) : Posse::Commands::Result
            Log.debug { "Routing #{command.class} to child #{child}" }

            {% if behaviors.empty? %}
              child.dispatch(command, **kwargs)
            {% else %}
              {% code = "child.dispatch(command, **kwargs)" %}
              {% for behavior in behaviors.reverse %}
                {% if behavior.is_a?(Path) || behavior.is_a?(Generic) %}
                  {% code = "#{behavior}.new.call(command, **kwargs) { #{code} }" %}
                {% else %}
                  {% code = "#{behavior}.call(command, **kwargs) { #{code} }" %}
                {% end %}
              {% end %}
              {{ code.id }}
            {% end %}
          end

          def self.dispatch(command : Posse::Commands::Command, **kwargs) : Posse::Commands::Result
            Log.debug { "Dispatching #{command.class}" }

            case command
            {% for method in @type.methods %}
              {% if mount_annotation = method.annotation(Posse::Commands::Mount) %}
                {% child = mount_annotation[0] %}
                {% for child_method in child.methods %}
                  {% if route_annotation = child_method.annotation(Posse::Commands::Route) %}
                  when {{ route_annotation[:command] }}
                    route_to_child({{ child }}, command, **kwargs)
                  {% end %}
                {% end %}
              {% end %}
            {% end %}
            else
              Log.warn { "No route found for #{command.class}" }

              raise Posse::Commands::Exceptions::UnhandledCommand.new(
                command,
                router_name: {{ @type.name.stringify }}
              )
            end
          end

          {% for method in @type.methods %}
            {% if mount_annotation = method.annotation(Posse::Commands::Mount) %}
              {% child = mount_annotation[0] %}
              {% for child_method in child.methods %}
                {% if route_annotation = child_method.annotation(Posse::Commands::Route) %}
                  def self.dispatch(command : {{ route_annotation[:command] }}, **kwargs) : Posse::Commands::Result
                    Log.debug { "Dispatching #{command.class} directly to #{ {{ child.stringify }} }" }
                    route_to_child({{ child }}, command, **kwargs)
                  end
                {% end %}
              {% end %}
            {% end %}
          {% end %}
        end
      end

      macro use(behavior)
        @[Posse::Commands::Behavior({{ behavior }})]
        def self._composite_behavior__{{ @type.methods.size }}
        end
      end

      macro router(*router_classes)
        {% for router_class in router_classes %}
          @[Posse::Commands::Mount({{ router_class }})]
          def self._mount__{{ router_class.id.stringify.underscore.gsub(/::/, "__") }}
          end
        {% end %}
      end
    end
  end
end
