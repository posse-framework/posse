module Posse
  module Projectors
    class Multi
      Log = ::Log.for(self)

      record Operation, kind : Kind, key : String, payload : Posse::Value?

      getter operations = [] of Operation
      property version_track : VersionTrack? = nil

      def track_version(projection_name : String, event_number : Int64)
        @version_track = VersionTrack.new(projection_name, event_number)
        self
      end

      def insert(key : String, value)
        @operations << Operation.new(Kind::Insert, key, Posse::Value.new(value))
        self
      end

      def update(key : String, value)
        @operations << Operation.new(Kind::Update, key, Posse::Value.new(value))
        self
      end

      def delete(key : String)
        @operations << Operation.new(Kind::Delete, key, nil)
        self
      end

      def empty? : Bool
        @operations.empty? && @version_track.nil?
      end
    end
  end
end
