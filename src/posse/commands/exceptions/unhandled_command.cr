module Posse
  module Commands
    module Exceptions
      class UnhandledCommand < Exception
        getter command_name : String?

        def initialize(message : String)
          super(message)
        end

        def initialize(command : Command, router_name : String? = nil)
          @command_name = command.class.name
          message = if router_name
                      "No route registered in #{router_name} for command: #{@command_name}"
                    else
                      "No route registered for command: #{@command_name}"
                    end
          super(message)
        end
      end
    end
  end
end
