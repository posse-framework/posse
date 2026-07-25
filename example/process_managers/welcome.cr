module Example
  module ProcessManagers
    class Welcome
      include Posse::ProcessManagers::ProcessManager

      router Example::Router
      store Posse::Projectors::Stores::InMemory

      react Events::UserRegistered do |event, _metadata, router|
        router.dispatch(
          Commands::SendWelcome.new(id: event.id, email: event.email),
          consistency: Posse::Commands::Consistency::Kind::Strong
        )
      end
    end
  end
end
