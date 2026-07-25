module Posse
  module EventStore
    module Exceptions
      class NotImplemented < Exception
        def initialize(event_store_type : String, method_name : String)
          super("#{event_store_type} includes Posse::EventStore::Base but does not implement ##{method_name}")
        end
      end
    end
  end
end
