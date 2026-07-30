module Example
  module Projectors
    class User
      include Posse::Projectors::Projector

      store Posse::Projectors::Stores::InMemory

      project Events::UserRegistered do |event, _metadata, multi|
        projection = Projections::User.new(
          id: event.id,
          first_name: event.first_name,
          last_name: event.last_name,
          email: event.email,
          password: event.password
        )

        multi.insert("user:#{event.id}", JSON.parse(projection.to_json))
      end

      project Events::UserFirstNameChanged do |event, _metadata, multi|
        if current = store.get("user:#{event.id}", Projections::User)
          current.first_name = event.first_name
          multi.update("user:#{event.id}", JSON.parse(current.to_json))
        end
      end

      project Events::WelcomeSent do |_event, _metadata, multi|
        multi
      end
    end
  end
end
