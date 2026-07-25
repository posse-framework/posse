module Posse
  module ProcessManagers
    module Exceptions
      class RouterNotConfigured < Exception
        def initialize(process_manager_name : String)
          super("#{process_manager_name} has no router configured — call `router SomeRouter` in the class body")
        end
      end
    end
  end
end
