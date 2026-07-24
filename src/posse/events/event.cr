module Posse
  module Events
    module Event
      macro included
        Log = ::Log.for(self)

        include JSON::Serializable

        def self.schema_type : String
          name
        end

        def self.schema_version : Int64
          1_i64
        end

        def self.upcast(json : JSON::Any, from_version : Int64) : JSON::Any
          json
        end

        def self.from_json_with_upcast(raw_json : String, payload_version : Int64)
          current_version = payload_version
          target_version = self.schema_version

          if current_version < target_version
            Log.debug { "Upcasting #{schema_type} from version #{current_version} to #{target_version}" }

            parsed = JSON.parse(raw_json)

            while current_version < target_version
              Log.debug { "Applying upcast step #{current_version} -> #{current_version + 1}" }
              parsed = upcast(parsed, current_version)
              current_version += 1
            end

            from_json(parsed.to_json)
          elsif current_version > target_version
            Log.warn { "#{schema_type} payload version #{current_version} is newer than known schema version #{target_version}, attempting to deserialize as-is" }
            from_json(raw_json)
          else
            from_json(raw_json)
          end
        end
      end

      def schema_type : String
        self.class.schema_type
      end

      def schema_version : Int64
        self.class.schema_version
      end
    end
  end
end
