module Posse
  module Aggregates
    module Aggregate
      macro included
        Log = ::Log.for(self)

        @@snapshot_store : Posse::Aggregates::Stores::Store? = nil
        @@snapshot_every : Int64? = nil

        def self.snapshot_store : Posse::Aggregates::Stores::Store?
          @@snapshot_store
        end

        def self.snapshot_every : Int64?
          @@snapshot_every
        end

        @version : Int64 = 0_i64
        @changes = [] of Posse::Events::Event

        getter version : Int64
        getter changes : Array(Posse::Events::Event)

        def initialize
        end

        def initialize(events : Enumerable(Posse::Events::Event))
          hydrate(events)
        end

        def initialize(snapshot : Posse::Aggregates::Snapshot, events : Enumerable(Posse::Events::Event))
          hydrate_from_snapshot(snapshot, events)
        end

        def apply(event : Posse::Events::Event)
          Log.debug { "Applying #{event.class}" }

          on(event)
          @changes << event
          @version += 1_i64
        end

        def hydrate(events : Enumerable(Posse::Events::Event))
          Log.debug { "Hydrating from #{events.size} event(s), starting at version #{@version}" }

          events.each do |event|
            on(event)
            @version += 1_i64
          end

          Log.debug { "Hydrated to version #{@version}" }
        end

        def hydrate_from_snapshot(snapshot : Posse::Aggregates::Snapshot, events : Enumerable(Posse::Events::Event))
          Log.debug { "Restoring from snapshot at version #{snapshot.version} (schema v#{snapshot.schema_version})" }

          restore_snapshot_with_upcast(snapshot)
          @version = snapshot.version

          hydrate(events)
        end

        def clear_changes
          Log.debug { "Clearing #{@changes.size} change(s)" }
          @changes.clear
        end

        def on(event : Posse::Events::Event)
        end

        def self.snapshot_schema_version : Int64
          1_i64
        end

        def self.upcast_snapshot(payload : JSON::Any, from_version : Int64) : JSON::Any
          payload
        end

        def to_snapshot_payload : String
          raise Posse::Aggregates::Exceptions::SnapshotNotSupported.new(self.class.name)
        end

        def restore_snapshot(snapshot : Posse::Aggregates::Snapshot) : Nil
          raise Posse::Aggregates::Exceptions::SnapshotNotSupported.new(self.class.name)
        end

        private def restore_snapshot_with_upcast(snapshot : Posse::Aggregates::Snapshot) : Nil
          current_version = snapshot.schema_version
          target_version = self.class.snapshot_schema_version

          if current_version < target_version
            Log.debug { "Upcasting snapshot for #{self.class.name} from schema v#{current_version} to v#{target_version}" }

            payload = JSON.parse(snapshot.payload)

            while current_version < target_version
              payload = self.class.upcast_snapshot(payload, current_version)
              current_version += 1_i64
            end

            restore_snapshot(Posse::Aggregates::Snapshot.new(
              aggregate_type: snapshot.aggregate_type,
              schema_version: target_version,
              version: snapshot.version,
              payload: payload.to_json
            ))
          elsif current_version > target_version
            Log.warn { "Snapshot schema v#{current_version} for #{self.class.name} is newer than known schema v#{target_version}, attempting to restore as-is" }
            restore_snapshot(snapshot)
          else
            restore_snapshot(snapshot)
          end
        end

        def to_snapshot : Posse::Aggregates::Snapshot
          Posse::Aggregates::Snapshot.new(
            aggregate_type: self.class.name,
            schema_version: self.class.snapshot_schema_version,
            version: @version,
            payload: to_snapshot_payload
          )
        end
      end

      macro snapshot(store_expression, every = 100)
        {% if store_expression.is_a?(Call) %}
          @@snapshot_store = {{ store_expression }}
        {% else %}
          @@snapshot_store = {{ store_expression }}.new
        {% end %}

        @@snapshot_every = {{ every }}_i64
      end
    end
  end
end
