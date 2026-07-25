module Example
  module Events
    struct WelcomeSent
      include Posse::Events::Event

      property id : String
      property email : String

      def initialize(@id : String, @email : String)
      end
    end
  end
end
