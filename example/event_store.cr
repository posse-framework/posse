module Example
  class EventStore
    include Posse::EventStore::Base

    Log = ::Log.for("posse.event_store")

    def initialize
      @streams = Hash(String, Array(Posse::Events::Event)).new { |h, k| h[k] = [] of Posse::Events::Event }
      @subscribers = [] of Proc(Posse::Events::Event, Hash(String, Posse::Value), Nil)
      @mutex = Mutex.new
    end

    def append(stream_id : String, expected_version : Int64, events : Array(Posse::Events::Event)) : Int64
      new_events_with_versions = @mutex.synchronize do
        stream = @streams[stream_id]
        current_version = stream.size.to_i64

        if current_version != expected_version
          raise Exception.new("Concurrency conflict for stream '#{stream_id}'")
        end

        events.each_with_index.map do |event, index|
          event_version = expected_version + index + 1
          stream << event
          {event, event_version}
        end.to_a
      end

      new_events_with_versions.each do |event, event_version|
        metadata = Hash(String, Posse::Value){
          "stream_id"    => Posse::Value.new(stream_id),
          "event_number" => Posse::Value.new(event_version),
          "appended_at"  => Posse::Value.new(Time.utc.to_s),
        }

        publish(event, metadata)
      end

      expected_version + events.size
    end

    def load(stream_id : String) : Array(Posse::Events::Event)
      events = @mutex.synchronize { @streams[stream_id]?.try(&.dup) } || [] of Posse::Events::Event
      Log.debug { "Loaded #{events.size} historical event(s) from stream '#{stream_id}'" }
      events
    end

    def load(stream_id : String, after_version : Int64) : Array(Posse::Events::Event)
      events = @mutex.synchronize do
        @streams[stream_id]?.try(&.skip(after_version).to_a)
      end || [] of Posse::Events::Event

      Log.debug { "Loaded #{events.size} event(s) from stream '#{stream_id}' after version #{after_version}" }
      events
    end

    def subscribe(&block : Posse::Events::Event, Hash(String, Posse::Value) -> Nil) : Nil
      @mutex.synchronize { @subscribers << block }
    end

    private def publish(event : Posse::Events::Event, metadata : Hash(String, Posse::Value)) : Nil
      subscribers = @mutex.synchronize { @subscribers.dup }
      Log.debug { "Notifying #{subscribers.size} subscriber(s) for event #{event.class.name}" }
      subscribers.each(&.call(event, metadata))
    end
  end
end
