module Posse
  module Pipelines
    class Pipeline
      Log = ::Log.for(self)

      property command : Posse::Commands::Command
      property aggregate_id : String
      property response : Posse::Commands::Result?
      property exception : Exception?
      getter? halted : Bool = false

      @assigns : Hash(String, JSON::Any)? = nil

      def initialize(@command, @aggregate_id)
        Log.debug { "Initialized pipeline for aggregate_id=#{@aggregate_id} command=#{@command.class}" }
      end

      def halt : self
        Log.debug { "Halting pipeline for aggregate_id=#{@aggregate_id}" }
        @halted = true
        self
      end

      def assign(key : String, value : T) : self forall T
        Log.debug { "Assigning key=#{key} type=#{T}" }
        (@assigns ||= Hash(String, JSON::Any).new(initial_capacity: 4))[key] = JSON::Any.new(value)
        self
      end

      def assigns : Hash(String, JSON::Any)
        @assigns ||= Hash(String, JSON::Any).new(initial_capacity: 4)
      end

      def fetch(key : String, type : T.class) : T forall T
        Log.debug { "Fetching key=#{key} type=#{T}" }
        assigns[key].as(Box(T)).value
      end

      def fetch?(key : String, type : T.class) : T? forall T
        Log.debug { "Fetching (optional) key=#{key} type=#{T}" }
        @assigns.try(&.[key]?).try(&.as?(Box(T))).try(&.value)
      end
    end
  end
end
