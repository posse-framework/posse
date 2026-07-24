module Posse
  module Aggregates
    struct Snapshot
      getter aggregate_type : String
      getter schema_version : Int64 = 1_i64
      getter version : Int64
      getter payload : String

      def initialize(@aggregate_type, @schema_version, @version, @payload)
      end
    end
  end
end
