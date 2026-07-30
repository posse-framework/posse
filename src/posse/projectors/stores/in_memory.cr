require "./store"

module Posse
  module Projectors
    module Stores
      class InMemory
        Log = ::Log.for(self)

        include Posse::Projectors::Stores::Store

        getter records = Hash(String, JSON::Any).new
        getter versions = Hash(String, Int64).new

        def initialize
          @mutex = Mutex.new
        end

        def get(key : String, type : T.class) : T? forall T
          @mutex.synchronize do
            if payload = @records[key]?
              T.from_json(payload.to_json)
            end
          end
        end

        def commit(multi : Posse::Projectors::Multi) : Nil
          @mutex.synchronize do
            if version = multi.version_track
              current_last_seen = @versions[version.projection_name]? || 0_i64

              if version.last_seen_event_number <= current_last_seen
                Log.warn { "Skipping already-seen event #{version.last_seen_event_number} for #{version.projection_name} (last seen: #{current_last_seen})" }

                raise Posse::Projectors::Exceptions::AlreadySeenEvent.new(
                  version.projection_name,
                  version.last_seen_event_number
                )
              end

              Log.debug { "Tracking version #{version.last_seen_event_number} for #{version.projection_name} (was: #{current_last_seen})" }
              @versions[version.projection_name] = version.last_seen_event_number
            end

            multi.actions.each(&.call)

            Log.debug { "Committing #{multi.operations.size} operation(s)" }

            multi.operations.each do |operation|
              case operation.kind
              in .insert?, .update?, .upsert?
                if payload = operation.payload
                  @records[operation.key] = payload
                end
              in .delete?
                @records.delete(operation.key)
              end
            end
          end
        end
      end
    end
  end
end
