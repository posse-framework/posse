module Example
  module Events
    struct UserFirstNameChanged
      include Posse::Events::Event

      property id : String
      property first_name : String

      def initialize(@id : String, @first_name : String)
      end
    end
  end
end
