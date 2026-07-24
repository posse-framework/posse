module Posse
  module Commands
    class Result
      getter aggregate_id : String
      getter aggregate_version : Int64

      getter events : Array(Posse::Events::Event)

      def initialize(
        @aggregate_id : String,
        @aggregate_version : Int64,
        @events : Array(Posse::Events::Event) = [] of Posse::Events::Event,
      )
      end

      def size : Int32
        @events.size
      end

      def events? : Bool
        !@events.empty?
      end

      def event(type : T.class) : T? forall T
        @events.find { |e| e.is_a?(T) }.as?(T)
      end

      def event!(type : T.class) : T forall T
        event(type) || raise Posse::Commands::Exceptions::EventNotFound.new("Expected event of type #{T.name} in result, but none was found.")
      end

      def events_of(type : T.class) : Array(T) forall T
        matched = [] of T

        @events.each do |e|
          matched << e if e.is_a?(T)
        end

        matched
      end
    end
  end
end
