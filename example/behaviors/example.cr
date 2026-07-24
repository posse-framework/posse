module Example
  module Behaviors
    class Example
      include Posse::Behaviors::Behavior

      def before_dispatch(pipeline : Posse::Pipelines::Pipeline) : Posse::Pipelines::Pipeline
        pipeline
      end

      def after_dispatch(pipeline : Posse::Pipelines::Pipeline) : Posse::Pipelines::Pipeline
        pipeline
      end

      def after_failure(pipeline : Posse::Pipelines::Pipeline) : Posse::Pipelines::Pipeline
        pipeline
      end
    end
  end
end
