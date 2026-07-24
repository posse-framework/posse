module Posse
  module Commands
    module Exceptions
      class EventNotFound < Exception
        def initialize(message : String = "Expected event was not found in result")
          super(message)
        end
      end
    end
  end
end
