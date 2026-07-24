module Posse
  module Projectors
    module Stores
      module Store
        abstract def get(key : String, type : T.class) forall T
        abstract def commit(multi : Posse::Projectors::Multi) : Nil
      end
    end
  end
end
