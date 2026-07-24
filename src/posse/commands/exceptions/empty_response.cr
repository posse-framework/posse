module Posse
  module Commands
    module Exceptions
      class EmptyResponse < Exception
        def initialize(message : String = "Expected a pipeline response")
          super(message)
        end
      end
    end
  end
end
