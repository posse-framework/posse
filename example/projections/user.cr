module Example
  module Projections
    class User
      include Posse::Projections::Projection

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
