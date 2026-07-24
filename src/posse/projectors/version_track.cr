module Posse
  module Projectors
    class VersionTrack
      property projection_name : String
      property last_seen_event_number : Int64

      def initialize(@projection_name, @last_seen_event_number)
      end
    end
  end
end
