module Example
  module Commands
    class RegisterUser
      include Posse::Commands::Command

      property id : String
      property first_name : String
      property last_name : String
      property email : String
      property password : String

      def initialize(@id : String, @first_name : String, @last_name : String, @email : String, @password : String)
      end
    end
  end
end
