module Example
  module Commands
    class SendWelcome
      include Posse::Commands::Command

      property id : String
      property email : String

      def initialize(@id : String, @email : String)
      end
    end
  end
end
