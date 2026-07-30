module Posse
  module Projectors
    class Multi
      Log = ::Log.for(self)

      record Operation, kind : Kind, key : String, payload : JSON::Any?

      getter actions = [] of Proc(Nil)
      getter operations = [] of Operation
      property version_track : VersionTrack? = nil

      def track_version(projection_name : String, event_number : Int64)
        @version_track = VersionTrack.new(projection_name, event_number)
        self
      end

      def insert(key : String, value : JSON::Any)
        @operations << Operation.new(Kind::Insert, key, value)
        self
      end

      def update(key : String, value : JSON::Any)
        @operations << Operation.new(Kind::Update, key, value)
        self
      end

      def upsert(key : String, value : JSON::Any)
        @operations << Operation.new(Kind::Upsert, key, value)
        self
      end

      def delete(key : String)
        @operations << Operation.new(Kind::Delete, key, nil)
        self
      end

      def add(&block : -> Nil)
        @actions << block
        self
      end

      def empty? : Bool
        @operations.empty? && @actions.empty? && @version_track.nil?
      end
    end
  end
end
