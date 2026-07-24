module Posse
  module Aggregates
    module Exceptions
      class SnapshotNotSupported < Exception
        def initialize(aggregate_type : String)
          super("#{aggregate_type} does not implement to_snapshot_payload/restore_snapshot")
        end
      end
    end
  end
end
