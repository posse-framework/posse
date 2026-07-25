module Posse
  module EventStore
    class InMemory
      include Posse::EventStore::Base

      record Job,
        events : Array(Posse::Events::Event),
        expected_version : Int64,
        result_channel : Channel(Int64 | Exception)

      def initialize
        @streams = Hash(String, Array(Posse::Events::Event)).new { |hash, key| hash[key] = [] of Posse::Events::Event }
        @subscribers = [] of Tuple(String, Proc(Posse::Events::Event, Hash(String, Posse::Value), Nil))
        @mutex = Mutex.new

        @stream_queues = Hash(String, Channel(Job)).new
        @worker_fibers = Hash(String, Fiber).new
        @workers_started = Set(String).new
      end

      def append(stream_id : String, expected_version : Int64, events : Array(Posse::Events::Event), consistency : Posse::Commands::Consistency::Any = Posse::Commands::Consistency::Kind::Strong) : Int64
        worker_fiber = @mutex.synchronize { @worker_fibers[stream_id]? }

        if worker_fiber == Fiber.current
          Log.debug { "Reentrant append on stream '#{stream_id}', processing inline" }

          result_channel = Channel(Int64 | Exception).new(1)
          process_job(stream_id, Job.new(events, expected_version, result_channel))

          result = result_channel.receive
          raise result if result.is_a?(Exception)

          wait_for_consistency(consistency, result)
          return result
        end

        queue = ensure_worker!(stream_id)
        result_channel = Channel(Int64 | Exception).new(1)

        queue.send(Job.new(events, expected_version, result_channel))

        result = result_channel.receive
        raise result if result.is_a?(Exception)

        wait_for_consistency(consistency, result)

        result
      end

      def load(stream_id : String) : Array(Posse::Events::Event)
        events = @mutex.synchronize { @streams[stream_id]?.try(&.dup) } || [] of Posse::Events::Event
        Log.debug { "Loaded #{events.size} historical event(s) from stream '#{stream_id}'" }
        events
      end

      def load(stream_id : String, after_version : Int64) : Array(Posse::Events::Event)
        events = @mutex.synchronize { @streams[stream_id]?.try(&.skip(after_version).to_a) } || [] of Posse::Events::Event
        Log.debug { "Loaded #{events.size} event(s) from stream '#{stream_id}' after version #{after_version}" }
        events
      end

      def subscribe(subscriber_name : String, &block : Posse::Events::Event, Hash(String, Posse::Value) -> Nil) : Nil
        @tracker_mutex.synchronize { @registered_handler_names << subscriber_name }
        @mutex.synchronize { @subscribers << {subscriber_name, block} }
      end

      private def ensure_worker!(stream_id : String) : Channel(Job)
        @mutex.synchronize do
          queue = @stream_queues[stream_id] ||= Channel(Job).new(64)

          unless @workers_started.includes?(stream_id)
            @workers_started << stream_id
            Log.debug { "Starting append/notify worker for stream '#{stream_id}'" }

            spawn name: "event_store:worker:#{stream_id}" do
              @mutex.synchronize { @worker_fibers[stream_id] = Fiber.current }

              loop do
                job = queue.receive
                process_job(stream_id, job)
              end
            end
          end

          queue
        end
      end

      private def process_job(stream_id : String, job : Job) : Nil
        current_version = @mutex.synchronize { @streams[stream_id].size.to_i64 }

        if current_version != job.expected_version
          Log.warn { "Concurrency conflict on stream '#{stream_id}': expected #{job.expected_version}, found #{current_version}" }
          job.result_channel.send(Posse::EventStore::Exceptions::ConcurrencyConflict.new(stream_id, job.expected_version))
          return
        end

        new_events_with_versions = [] of Tuple(Posse::Events::Event, Int64)

        begin
          new_events_with_versions = job.events.each_with_index.map do |event, index|
            event_version = job.expected_version + index + 1
            @mutex.synchronize { @streams[stream_id] << event }
            {event, event_version}
          end.to_a
        rescue ex
          Log.error(exception: ex) { "Append failed for stream '#{stream_id}'" }
          job.result_channel.send(ex)
          return
        end

        new_version = job.expected_version + job.events.size
        Log.debug { "Appended #{job.events.size} event(s) to stream '#{stream_id}', new version #{new_version}" }

        job.result_channel.send(new_version)

        new_events_with_versions.each do |event, v|
          publish(event, build_metadata(stream_id, v))
        end
      end

      private def publish(event : Posse::Events::Event, metadata : Hash(String, Posse::Value)) : Nil
        subscribers = @mutex.synchronize { @subscribers.dup }
        Log.debug { "Notifying #{subscribers.size} subscriber(s) for event #{event.class.name}" }

        subscribers.each do |subscriber_name, subscriber_block|
          subscriber_block.call(event, metadata)
        rescue ex
          Log.error(exception: ex) { "Subscriber '#{subscriber_name}' raised while handling #{event.class}" }
        end
      end

      private def build_metadata(stream_id : String, event_version : Int64) : Hash(String, Posse::Value)
        Hash(String, Posse::Value){
          "stream_id"    => Posse::Value.new(stream_id),
          "event_number" => Posse::Value.new(event_version),
          "appended_at"  => Posse::Value.new(Time.utc.to_s),
        }
      end
    end
  end
end
