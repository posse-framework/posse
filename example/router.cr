module Example
  class Router
    include Posse::Commands::Router

    event_store Posse::EventStore::InMemory

    use Behaviors::Example

    dispatch [Commands::RegisterUser, Commands::ChangeUserFirstName, Commands::SendWelcome],
      to: Aggregates::User,
      identity: id
  end
end
