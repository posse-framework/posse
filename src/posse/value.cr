module Posse
  abstract class Value
    def self.new(value : Posse::Value)
      value
    end

    def self.new(value : T) forall T
      Box(T).new(value)
    end

    def raw(type : T.class) : T forall T
      if box = self.as?(Box(T))
        box.value
      else
        raise TypeCastError.new("Expected Posse::Value holding #{T}, but holds #{self.class}")
      end
    end
  end

  private class Box(T) < Value
    getter value : T

    def initialize(@value : T)
    end
  end
end
