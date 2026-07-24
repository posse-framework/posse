module Posse
  module Aggregates
    module Stores
      module Store
        abstract def get(aggregate_id : String) : Posse::Aggregates::Snapshot?
        abstract def put(aggregate_id : String, snapshot : Posse::Aggregates::Snapshot) : Nil
      end
    end
  end
end
