module Posse
  module Events
    module Exceptions
      class UnknownEvent < Exception
        getter schema_type : String

        def initialize(@schema_type : String)
          super("No registered event handler found for schema_type: '#{@schema_type}'")
        end
      end
    end
  end
end
