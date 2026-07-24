module Example
  module Commands
    class ChangeUserFirstName
      include Posse::Commands::Command

      property id : String
      property first_name : String

      def initialize(@id : String, @first_name : String)
      end
    end
  end
end
