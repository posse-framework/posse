module Example
  class Router
    include Posse::Commands::Router

    event_store EventStore

    use Behaviors::Example

    dispatch [Commands::RegisterUser, Commands::ChangeUserFirstName],
      to: Aggregates::User,
      identity: id
  end
end
