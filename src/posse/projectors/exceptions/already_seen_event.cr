module Posse
  module Projectors
    module Exceptions
      class AlreadySeenEvent < Exception
        getter projection_name : String
        getter event_number : Int64

        def initialize(@projection_name, @event_number)
          super("Event #{event_number} already processed by projection '#{projection_name}'")
        end
      end
    end
  end
end
