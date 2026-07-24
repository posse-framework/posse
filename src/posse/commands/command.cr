module Posse
  module Commands
    module Command
      macro included
        Log = ::Log.for(self)

        include JSON::Serializable
      end
    end
  end
end
