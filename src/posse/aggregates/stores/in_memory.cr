require "./store"

module Posse
  module Aggregates
    module Stores
      class InMemory
        Log = ::Log.for(self)

        include Posse::Aggregates::Stores::Store

        def initialize
          @mutex = Mutex.new
          @snapshots = Hash(String, Posse::Aggregates::Snapshot).new
        end

        def get(aggregate_id : String) : Posse::Aggregates::Snapshot?
          @mutex.synchronize { @snapshots[aggregate_id]? }
        end

        def put(aggregate_id : String, snapshot : Posse::Aggregates::Snapshot) : Nil
          @mutex.synchronize do
            Log.debug { "Storing snapshot for #{aggregate_id} at version #{snapshot.version}" }
            @snapshots[aggregate_id] = snapshot
          end
        end
      end
    end
  end
end
