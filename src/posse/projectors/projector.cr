module Posse
  module Projectors
    module Projector
      macro included
        Log = ::Log.for(self)

        def self.after_update(event : Posse::Events::Event, metadata : Hash(String, Posse::Value), multi : Posse::Projectors::Multi) : Nil
        end

        macro finished
          \{% handlers = [] of ASTNode %}
          \{% for method in @type.class.methods %}
            \{% if method.name.stringify.starts_with?("_handle_") %}
              \{% handlers << method %}
            \{% end %}
          \{% end %}

          def self.handle(event : Posse::Events::Event, metadata : Hash(String, Posse::Value)) : Nil
            \{% if handlers.empty? %}
              Log.debug { "No handlers registered, skipping event #{event.class}" }
              return
            \{% else %}
              multi = Posse::Projectors::Multi.new

              case event
              \{% for method in handlers %}
              when \{{ method.args[0].restriction }}
                Log.debug { "Handling #{event.class}" }

                if event_number_value = metadata["event_number"]?
                  multi.track_version(self.name, event_number_value.raw(Int64))
                end

                \{{ method.name }}(event, metadata, multi)
              \{% end %}
              else
                Log.debug { "No matching handler for #{event.class}, skipping" }
                return
              end

              if multi.empty?
                Log.debug { "No operations produced for #{event.class}, skipping commit" }
                return
              end

              begin
                store.commit(multi)
                Log.debug { "Committed #{multi.operations.size} operation(s) for #{event.class}" }
                after_update(event, metadata, multi)
              rescue exception : Posse::Projectors::Exceptions::AlreadySeenEvent
                Log.warn { "Already-seen event for #{self.name}: #{exception.message}" }
                nil
              end
            \{% end %}
          end
        end
      end

      macro project(event_type, &block)
        {%
          method_name = ("_handle_" + event_type.stringify.gsub(/[^a-zA-Z0-9_]/, "_") + "_" + block.line_number.stringify).id

          event_argument = block.args[0] || "_event".id
          meta_argument = "_metadata".id
          multi_argument = "_multi".id

          if block.args.size == 3
            meta_argument = block.args[1]
            multi_argument = block.args[2]
          elsif block.args.size == 2
            if ["metadata", "meta"].includes?(block.args[1].stringify)
              meta_argument = block.args[1]
            else
              multi_argument = block.args[1]
            end
          end
        %}

        def self.{{ method_name }}(
          {{ event_argument }} : {{ event_type }},
          {{ meta_argument }}  : Hash(String, Posse::Value),
          {{ multi_argument }} : Posse::Projectors::Multi
        )
          {{ block.body }}
        end
      end

      macro store(instance)
        @@store : Posse::Projectors::Stores::Store? = nil

        def self.store : Posse::Projectors::Stores::Store
          @@store ||= (
            {% if instance.is_a?(Call) %}
              {{ instance }}
            {% else %}
              {{ instance }}.new
            {% end %}
          )
        end
      end
    end
  end
end
