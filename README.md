<p align="center" width="100%">
    <img src="https://github.com/posse-framework.png" height="250" href="https://github.com/posse-framework/posse">
</p>

<p align="center">
    A light, type-safe <ins>CQRS</ins> and <ins>event sourcing</ins> framework
</p>

Posse is a framework for building event-sourced, domain-driven applications. It is designed to be modular, type-safe, and capable of scaling up to the performance limits of the Crystal programming language. Heavily inspired by Elixir's [Commanded](https://github.com/commanded/commanded), Posse offers fine-grained surgical consistency controls, actor-like fiber concurrency, and bulletproof event logs with zero operational bloat.

## Motivation

This project exists due to the fact that typical event-sourcing setups lack rigid architecture and structural patterns in Crystal, while maintaining maximum hardware performance without asynchronous bottlenecks.

## Features

* Blazing fast performance leveraging Crystal's compiled native runtime and lightweight fibers.
* Surgical consistency control (`Wait[Class]`) allowing dynamic synchronization at the call site.
* Expressive and type-safe domain modeling for Routers, Aggregates, Projectors, and Sagas.
* Fiber-safe concurrency built natively on thread-safe primitives, mutexes, and channels.
* Zero operational bloat with modular architecture inspired by Elixir's Commanded.

## Code example

Add this to your application's router and domain models:

```crystal
module Untitled
  class Router
    include Posse::Commands::Router

    event_store Posse::EventStore::InMemory
    use Behaviors::Untitled

    dispatch [Commands::RegisterUser, Commands::ChangeUserFirstName, Commands::SendWelcome],
      to: Aggregates::User,
      identity: id
  end
end

module Untitled
  module Projectors
    class User
      include Posse::Projectors::Projector

      store Posse::Projectors::Stores::InMemory

      project Events::UserRegistered do |event, _metadata, multi|
        projection = Projections::User.new(
          id: event.id, first_name: event.first_name, last_name: event.last_name,
          email: event.email, password: event.password
        )
        multi.insert("user:#{event.id}", Posse::Value.new(projection))
      end
    end
  end
end

module Untitled
  module ProcessManagers
    class Welcome
      include Posse::ProcessManagers::ProcessManager

      router Untitled::Router
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
```

To dispatch commands with surgical consistency:

```crystal
id = UUID.random.to_s

register_command = Untitled::Commands::RegisterUser.new(
  id: id,
  first_name: "John",
  last_name: "Doe",
  email: "john@doe.com",
  password: "Abcd1234!@#$"
)

Untitled::Router.dispatch(
  register_command,
  consistency: Posse::Commands::Consistency::Wait[Untitled::ProcessManagers::Welcome]
)
```

## Installation

Add this to your application's `shards.yml`:

```yaml
dependencies:
  posse:
    github: posse-framework/posse
```

And run this command in your terminal:

```bash
shards install
```

## Contribute

See our [contribution guidelines](https://github.com/posse-framework/posse/blob/master/CONTRIBUTING.md) and read the [code of conduct](https://github.com/posse-framework/posse/blob/master/CODE_OF_CONDUCT.md).
