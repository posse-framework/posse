module Posse
  module EventStore
    module Base
      abstract def append(stream_id : String, expected_version : Int64, events : Array(Posse::Events::Event)) : Int64
      abstract def load(stream_id : String) : Array(Posse::Events::Event)
      abstract def load(stream_id : String, after_version : Int64) : Array(Posse::Events::Event)
      abstract def subscribe(&block : Posse::Events::Event, Hash(String, Posse::Value) -> Nil) : Nil
    end
  end
end
