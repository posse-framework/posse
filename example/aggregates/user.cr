module Example
  module Aggregates
    class User
      include Posse::Aggregates::Aggregate

      snapshot Posse::Aggregates::Stores::InMemory, every: 50

      property id : String = String.new
      property first_name : String = String.new
      property last_name : String = String.new
      property email : String = String.new
      property password : String = String.new

      def execute(command : Commands::RegisterUser)
        apply(
          Events::UserRegistered.new(
            id: command.id,
            first_name: command.first_name,
            last_name: command.last_name,
            email: command.email,
            password: command.password
          )
        )
      end

      def execute(command : Commands::ChangeUserFirstName)
        apply(
          Events::UserFirstNameChanged.new(
            id: command.id,
            first_name: command.first_name
          )
        )
      end

      def on(event : Events::UserRegistered)
        @id = event.id
        @first_name = event.first_name
        @last_name = event.last_name
        @email = event.email
        @password = event.password
      end

      def on(event : Events::UserFirstNameChanged)
        @first_name = event.first_name
      end

      def to_snapshot_payload : String
        {
          id:         @id,
          first_name: @first_name,
          last_name:  @last_name,
          email:      @email,
          password:   @password,
        }.to_json
      end

      def restore_snapshot(snapshot : Posse::Aggregates::Snapshot) : Nil
        data = JSON.parse(snapshot.payload)

        @id         = data["id"].as_s
        @first_name = data["first_name"].as_s
        @last_name  = data["last_name"].as_s
        @email      = data["email"].as_s
        @password   = data["password"].as_s
      end
    end
  end
end
