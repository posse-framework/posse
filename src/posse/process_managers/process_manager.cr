module Posse
  module ProcessManagers
    module ProcessManager
      macro included
        Log = ::Log.for(self)

        @@router = nil
        @@store : Posse::Projectors::Stores::Store? = nil

        macro finished
          \{% handlers = [] of ASTNode %}

          \{% for m in @type.class.methods %}
            \{% if m.name.stringify.starts_with?("_react_") %}
              \{% handlers << m %}
            \{% end %}
          \{% end %}

          def self.handle(event : Posse::Events::Event, metadata : Hash(String, Posse::Value)) : Nil
            \{% if handlers.empty? %}
              Log.debug { "No reactions registered, skipping event #{event.class}" }
              return
            \{% else %}
              router = @@router || raise Posse::ProcessManagers::Exceptions::RouterNotConfigured.new(self.name)

              if store = @@store
                if event_number_value = metadata["event_number"]?
                  event_number = event_number_value.raw(Int64)
                  key = "process_manager_version:#{self.name}"

                  if current = store.get(key, Int64)
                    if event_number <= current
                      Log.warn { "Skipping already-seen event #{event_number} for #{self.name} (last seen: #{current})" }
                      return
                    end
                  end
                end
              end

              case event
              \{% for method in handlers %}
              when \{{ method.args[0].restriction }}
                Log.debug { "Reacting to #{event.class}" }
                \{{ method.name }}(event, metadata, router)
              \{% end %}
              else
                Log.debug { "No matching reaction for #{event.class}, skipping" }
                return
              end

              if store = @@store
                if event_number_value = metadata["event_number"]?
                  multi = Posse::Projectors::Multi.new
                  multi.upsert("process_manager_version:#{self.name}", event_number_value.raw(Int64))
                  store.commit(multi)
                  Log.debug { "Tracked version #{event_number_value.raw(Int64)} for #{self.name}" }
                end
              end
            \{% end %}
          end
        end
      end

      macro react(event_type, &block)
        {%
          method_name = ("_react_" + event_type.stringify.gsub(/[^a-zA-Z0-9_]/, "_") + "_" + block.line_number.stringify).id
          event_argument = block.args[0] || "_event".id
          meta_argument = block.args[1] || "_metadata".id
          router_argument = block.args[2] || "_router".id
        %}

        def self.{{ method_name }}(
          {{ event_argument }}  : {{ event_type }},
          {{ meta_argument }}   : Hash(String, Posse::Value),
          {{ router_argument }}
        )
          {{ block.body }}
        end
      end

      macro router(router_class)
        @@router = {{ router_class }}
      end

      macro store(store_expression)
        {% if store_expression.is_a?(Call) %}
          @@store = {{ store_expression }}
        {% else %}
          @@store = {{ store_expression }}.new
        {% end %}
      end
    end
  end
end
