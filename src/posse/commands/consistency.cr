module Posse
  module Commands
    module Consistency
      enum Kind
        Eventual
        Strong
      end

      record Wait, handlers : Array(String) do
        def self.[](*handlers)
          new(handlers.map(&.to_s).to_a)
        end
      end

      alias Any = Kind | Wait
    end
  end
end
