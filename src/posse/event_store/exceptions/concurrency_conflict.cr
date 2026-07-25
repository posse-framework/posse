module Posse
  module EventStore
    module Exceptions
      class ConcurrencyConflict < Exception
        getter stream_id : String
        getter expected_version : Int64

        def initialize(@stream_id : String, @expected_version : Int64)
          super("Concurrency conflict appending to stream '#{@stream_id}': expected version #{@expected_version}, but stream has moved on")
        end
      end
    end
  end
end
