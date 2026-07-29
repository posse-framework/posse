module Posse
  module Events
    module Registry
      macro finished
        def self.deserialize(schema_type : String, raw_json : String, version : Int64 = 1_i64) : Posse::Events::Event
          case schema_type
          {% for event_type in Posse::Events::Event.includers %}
          when {{ event_type }}.schema_type
            {{ event_type }}.from_json_with_upcast(raw_json, version).as(Posse::Events::Event)
          {% end %}
          else
            raise Posse::Events::Exceptions::UnknownEvent.new("No registered event handler found for schema_type: '#{schema_type}'")
          end
        end

        def self.deserialize?(schema_type : String, raw_json : String, version : Int64 = 1_i64) : Posse::Events::Event?
          case schema_type
          {% for event_type in Posse::Events::Event.includers %}
          when {{ event_type }}.schema_type
            {{ event_type }}.from_json_with_upcast(raw_json, version).as(Posse::Events::Event)
          {% end %}
          else
            nil
          end
        end

        def self.registered_schema_types : Array(String)
          [
            {% for event_type in Posse::Events::Event.includers %}
              {{ event_type }}.schema_type,
            {% end %}
          ] of String
        end
      end
    end
  end
end
