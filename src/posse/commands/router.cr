module Posse
  module Commands
    module Router
      macro included
        Log = ::Log.for(self)

        @@event_store : Posse::EventStore::Base? = nil
        @@subscribed_stores = Set(UInt64).new

        macro finished
          def self.event_store : Posse::EventStore::Base?
            if store = @@event_store
              ensure_subscriptions!(store)
            end

            @@event_store
          end

          def self.event_store=(store : Posse::EventStore::Base?)
            @@event_store = store

            if store
              ensure_subscriptions!(store)
            end
          end

          def self.ensure_subscriptions!(store : Posse::EventStore::Base)
            return if @@subscribed_stores.includes?(store.object_id)
            @@subscribed_stores << store.object_id

            Log.debug { "Subscribing store #{store.object_id}" }

            \{% for projector in Object.all_subclasses.select { |t| t.ancestors.includes?(Posse::Projectors::Projector) } %}
              store.subscribe(\{{ projector }}.name) do |event, metadata|
                \{{ projector }}.handle(event, metadata)

                if event_number = metadata["event_number"]?
                  store.acknowledge(\{{ projector }}.name, event_number.raw(Int64))
                end
              end
            \{% end %}

            \{% for process_manager in Object.all_subclasses.select { |t| t.ancestors.includes?(Posse::ProcessManagers::ProcessManager) } %}
              store.subscribe(\{{ process_manager }}.name) do |event, metadata|
                \{{ process_manager }}.handle(event, metadata)

                if event_number = metadata["event_number"]?
                  store.acknowledge(\{{ process_manager }}.name, event_number.raw(Int64))
                end
              end
            \{% end %}
          end

          def {{ @type }}.maybe_snapshot(aggregate_class, aggregate, aggregate_id : String, new_version : Int64, previous_snapshot : Posse::Aggregates::Snapshot?) : Nil
            return unless snapshot_store = aggregate_class.snapshot_store
            return unless snapshot_every = aggregate_class.snapshot_every

            since_last_snapshot = new_version - (previous_snapshot.try(&.version) || 0_i64)
            return if since_last_snapshot < snapshot_every

            snapshot_to_write = aggregate.to_snapshot

            Log.debug { "Scheduling async snapshot for #{aggregate_id} at version #{snapshot_to_write.version} (#{since_last_snapshot} events since last snapshot)" }

            spawn name: "snapshot:worker:#{aggregate_id}" do
              begin
                snapshot_store.put(aggregate_id, snapshot_to_write)
                Log.debug { "Snapshot committed for #{aggregate_id} at version #{snapshot_to_write.version}" }
              rescue ex
                Log.error(exception: ex) { "Failed to write snapshot for #{aggregate_id} at version #{snapshot_to_write.version}" }
              end
            end
          end

          def {{ @type }}.run_core_pipeline(aggregate_class, command, aggregate_id : String, store : Posse::EventStore::Base? = nil, consistency : Posse::Commands::Consistency::Any = Posse::Commands::Consistency::Kind::Eventual) : Posse::Commands::Result
            Log.debug { "Running core pipeline for #{aggregate_class} aggregate_id=#{aggregate_id} command=#{command.class}" }

            active_store = store || self.event_store
            ensure_subscriptions!(active_store) if active_store

            snapshot = aggregate_class.snapshot_store.try(&.get(aggregate_id))

            aggregate = if snapshot
              historical_events = active_store ? active_store.load(aggregate_id, after_version: snapshot.version) : ([] of Posse::Events::Event)
              Log.debug { "Loaded #{historical_events.size} event(s) since snapshot version #{snapshot.version}" }
              aggregate_class.new(snapshot, historical_events)
            else
              historical_events = active_store ? active_store.load(aggregate_id) : ([] of Posse::Events::Event)
              Log.debug { "Loaded #{historical_events.size} historical event(s) for aggregate_id=#{aggregate_id}" }
              aggregate_class.new(historical_events)
            end

            expected_version = aggregate.version

            aggregate.execute(command)

            new_events = aggregate.changes.dup
            aggregate.clear_changes

            Log.debug { "Produced #{new_events.size} new event(s) for aggregate_id=#{aggregate_id}" }

            new_version = if active_store
              active_store.append(aggregate_id, expected_version, new_events, consistency: consistency)
            else
              expected_version + new_events.size
            end

            Log.debug { "Committed aggregate_id=#{aggregate_id} at version #{new_version}" }

            maybe_snapshot(aggregate_class, aggregate, aggregate_id, new_version, snapshot)

            Posse::Commands::Result.new(
              aggregate_id: aggregate_id,
              aggregate_version: new_version,
              events: new_events
            )
          end
        end
      end

      macro event_store(store_expression)
        {% if store_expression.is_a?(Path) || store_expression.is_a?(Generic) %}
          @@event_store = {{ store_expression }}.new
        {% else %}
          @@event_store = {{ store_expression }}
        {% end %}
      end

      macro use(behavior)
        @[Posse::Commands::Behavior({{ behavior }})]
        def self._behavior_marker__{{ behavior.stringify.gsub(/[^a-zA-Z0-9_]/, "_").id }}
        end
      end

      macro dispatch(command_types, to aggregate_class, identity identity_field)
        {% command_list = command_types.is_a?(ArrayLiteral) ? command_types : [command_types] %}

        {% unless @type.has_method?(:execute_pipeline) %}
          def self.execute_pipeline(aggregate_class, command, aggregate_id : String, event_store : Posse::EventStore::Base? = nil, consistency : Posse::Commands::Consistency::Any = Posse::Commands::Consistency::Kind::Eventual, **kwargs) : Posse::Commands::Result
            {% behaviors = [] of ASTNode %}

            {% for method in @type.class.methods %}
              {% if ann = method.annotation(Posse::Commands::Behavior) %}
                {% behaviors << ann[0] %}
              {% end %}
            {% end %}

            Log.debug { "Dispatching #{command.class} for aggregate_id=#{aggregate_id} through #{ {{ behaviors.size }} } behavior(s)" }

            pipeline = Posse::Pipelines::Pipeline.new(command, aggregate_id)

            {% for behavior, index in behaviors %}
              {% if behavior.is_a?(Call) %}
                behavior_instance_{{ index }} = {{ behavior }}
              {% else %}
                behavior_instance_{{ index }} = {{ behavior }}.new
              {% end %}
            {% end %}

            {% for behavior, index in behaviors %}
              pipeline = behavior_instance_{{ index }}.before_dispatch(pipeline)

              if pipeline.halted?
                Log.debug { "Pipeline halted by {{ behavior.is_a?(Call) ? behavior.name : behavior }}" }

                if response = pipeline.response
                  return response
                else
                  raise Posse::Commands::Exceptions::EmptyResponse.new
                end
              end
            {% end %}

            begin
              pipeline.response = run_core_pipeline(aggregate_class, command, aggregate_id, store: event_store, consistency: consistency)
            rescue exception
              Log.error(exception: exception) { "Core pipeline failed for aggregate_id=#{aggregate_id}: #{exception.message}" }

              pipeline.exception = exception

              {% for behavior, forward_index in behaviors %}
                {% index = behaviors.size - 1 - forward_index %}
                pipeline = behavior_instance_{{ index }}.after_failure(pipeline)
              {% end %}

              raise exception
            end

            {% for behavior, forward_index in behaviors %}
              {% index = behaviors.size - 1 - forward_index %}
              pipeline = behavior_instance_{{ index }}.after_dispatch(pipeline)
            {% end %}

            if response = pipeline.response
              Log.debug { "Dispatch complete for aggregate_id=#{aggregate_id} at version #{response.aggregate_version}" }
              response
            else
              raise Posse::Commands::Exceptions::EmptyResponse.new
            end
          end
        {% end %}

        {% for command in command_list %}
          @[Posse::Commands::Route(command: {{ command }}, aggregate: {{ aggregate_class }}, identity: {{ identity_field }})]
          def self.dispatch(command : {{ command }}, **kwargs) : Posse::Commands::Result
            aggregate_id = command.{{ identity_field.id }}.to_s
            execute_pipeline({{ aggregate_class }}, command, aggregate_id, **kwargs)
          end
        {% end %}
      end
    end
  end
end
