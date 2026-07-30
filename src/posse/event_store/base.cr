module Posse
  module EventStore
    module Base
      macro included
        Log = ::Log.for(self)

        @tracker_mutex : Mutex = Mutex.new
        @handler_versions : Hash(String, Int64) = Hash(String, Int64).new(0_i64)
        @registered_handler_names : Set(String) = Set(String).new

        @waiters : Array(Channel(Nil)) = [] of Channel(Nil)

        def acknowledge(handler_name : String, version : Int64) : Nil
          waiters_to_wake = [] of Channel(Nil)

          @tracker_mutex.synchronize do
            @handler_versions[handler_name] = version
            waiters_to_wake = @waiters.dup
            @waiters.clear
          end

          waiters_to_wake.each do |ch|
            ch.close unless ch.closed?
          end
        end

        def wait_for_consistency(consistency : Posse::Commands::Consistency::Any, target_version : Int64, timeout : Time::Span = 5.seconds) : Nil
          case consistency
          when Posse::Commands::Consistency::Kind::Eventual
            return
          when Posse::Commands::Consistency::Kind::Strong
            wait_for_handlers(@registered_handler_names.to_a, target_version, timeout)
          when Posse::Commands::Consistency::Wait
            wait_for_handlers(consistency.handlers, target_version, timeout)
          end
        end

        private def wait_for_handlers(handlers : Array(String), target_version : Int64, wait_timeout : Time::Span)
          start_time = Time.monotonic

          loop do
            channel = nil

            @tracker_mutex.synchronize do
              if handlers.all? { |h| @handler_versions[h] >= target_version }
                return
              else
                channel = Channel(Nil).new
                @waiters << channel
              end
            end

            if channel
              elapsed = Time.monotonic - start_time
              remaining = wait_timeout - elapsed

              if remaining <= Time::Span.zero
                Log.warn { "Timeout waiting for handlers #{handlers} to reach version #{target_version}" }
                @tracker_mutex.synchronize { @waiters.delete(channel) }
                return
              end

              select
              when channel.receive?
                # Woken up by `acknowledge`. The loop will restart and evaluate the condition again.
              when timeout(remaining)
                Log.warn { "Timeout waiting for handlers #{handlers} to reach version #{target_version}" }
                @tracker_mutex.synchronize { @waiters.delete(channel) }
                return
              end
            end
          end
        end

        def append(stream_id : String, expected_version : Int64, events : Array(Posse::Events::Event), consistency : Posse::Commands::Consistency::Any = Posse::Commands::Consistency::Kind::Eventual) : Int64
          raise Posse::EventStore::Exceptions::NotImplemented.new(self.class.name, "append")
        end

        def load(stream_id : String) : Array(Posse::Events::Event)
          raise Posse::EventStore::Exceptions::NotImplemented.new(self.class.name, "load(stream_id)")
        end

        def load(stream_id : String, after_version : Int64) : Array(Posse::Events::Event)
          raise Posse::EventStore::Exceptions::NotImplemented.new(self.class.name, "load(stream_id, after_version)")
        end

        def subscribe(subscriber_name : String, &block : Posse::Events::Event, Hash(String, JSON::Any) -> Nil) : Nil
          @tracker_mutex.synchronize { @registered_handler_names << subscriber_name }
          raise Posse::EventStore::Exceptions::NotImplemented.new(self.class.name, "subscribe")
        end
      end
    end
  end
end
