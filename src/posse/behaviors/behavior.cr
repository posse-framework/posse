module Posse
  module Behaviors
    module Behavior
      abstract def before_dispatch(pipeline : Posse::Pipelines::Pipeline) : Posse::Pipelines::Pipeline
      abstract def after_dispatch(pipeline : Posse::Pipelines::Pipeline) : Posse::Pipelines::Pipeline
      abstract def after_failure(pipeline : Posse::Pipelines::Pipeline) : Posse::Pipelines::Pipeline
    end
  end
end
