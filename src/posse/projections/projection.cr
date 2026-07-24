module Posse
  module Projections
    module Projection
      macro included
        Log = ::Log.for(self)

        include JSON::Serializable
      end
    end
  end
end
