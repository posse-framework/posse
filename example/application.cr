require "log"
require "uuid"

require "../src/posse"
require "./**"

Log.setup(:warn)

DURATION_SECONDS = (ENV["DURATION"]? || "5").to_i

id = UUID.random.to_s

register_command = Example::Commands::RegisterUser.new(
  id: id,
  first_name: "John",
  last_name: "Doe",
  email: "john@doe.com",
  password: "Abcd1234!@#$"
)

pp Example::Router.event_store

# Mix up consistency on registration: use a targeted wait for the Welcome process manager
Example::Router.dispatch(
  register_command,
  consistency: Posse::Commands::Consistency::Wait[Example::ProcessManagers::Welcome]
)

update_command = Example::Commands::ChangeUserFirstName.new(
  id: id,
  first_name: "James"
)

succeeded = 0
failed = 0
errors = Hash(String, Int32).new(0)

started_at = Time.monotonic
deadline = started_at + DURATION_SECONDS.seconds

puts "Running randomized mixed-consistency stress on one aggregate for #{DURATION_SECONDS}s..."

# Define a pool of consistency strategies to rotate through randomly on every dispatch
consistency_strategies = [
  Posse::Commands::Consistency::Kind::Eventual,
  Posse::Commands::Consistency::Kind::Strong,
  Posse::Commands::Consistency::Wait[Example::Projectors::User],
  Posse::Commands::Consistency::Wait[Example::ProcessManagers::Welcome],
  Posse::Commands::Consistency::Wait[Example::Projectors::User, Example::ProcessManagers::Welcome]
]

loop do
  break if Time.monotonic >= deadline

  # Pick a random consistency mode for each iteration to stress different pathways
  chosen_consistency = consistency_strategies.sample

  begin
    Example::Router.dispatch(update_command, consistency: chosen_consistency)
    succeeded += 1
  rescue ex
    failed += 1
    errors[ex.class.to_s] += 1
  end
end

sleep 0.5.seconds

elapsed = (Time.monotonic - started_at).total_seconds
total = succeeded + failed

puts "-" * 60
puts "elapsed:     %.2fs" % elapsed
puts "succeeded:   #{succeeded}"
puts "failed:      #{failed}"
puts "throughput:  %.0f commands/sec" % (total / elapsed)

unless errors.empty?
  puts "\nerror breakdown:"
  errors.each { |klass, count| puts "  #{klass}: #{count}" }
end

snapshot_store = Example::Aggregates::User.snapshot_store.as(Posse::Aggregates::Stores::InMemory)
snapshot_every = Example::Aggregates::User.snapshot_every.not_nil!

store = Example::Projectors::User.store.as(Posse::Projectors::Stores::InMemory)
projector_version = store.versions["Example::Projectors::User"]? || 0_i64

puts "\nSnapshot cadence check (snapshot_every=#{snapshot_every}):"

if snapshot = snapshot_store.get(id)
  events_since_snapshot = projector_version - snapshot.version
  puts "  latest snapshot version: #{snapshot.version}"
  puts "  current projected version: #{projector_version}"
  puts "  events since last snapshot: #{events_since_snapshot}"

  if events_since_snapshot >= snapshot_every * 2
    puts "  WARNING: snapshot appears stale - more than 2x snapshot_every events behind, cadence may not be keeping up"
  else
    puts "  OK: snapshot cadence looks healthy"
  end
else
  puts "  WARNING: no snapshot found at all - either snapshotting never triggered, or the async write hasn't landed yet"
end

register_side_effects = 2_i64
expected_version = succeeded + register_side_effects

puts "\nVersion integrity check:"
puts "  final projected version: #{projector_version}"
puts "  expected version (#{succeeded} updates + #{register_side_effects} from register+welcome): #{expected_version}"

if projector_version == expected_version
  puts "  OK: versions line up exactly - no gaps, no collisions, no lost updates"
else
  puts "  WARNING: MISMATCH - projected version does not match total successful dispatches"
  puts "     (expected #{expected_version}, projector shows #{projector_version})"
end

if failed > 0 || (snapshot_store.get(id).nil?) || (projector_version != expected_version)
  exit 1
end
