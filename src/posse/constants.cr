module Posse
  module Constants
    VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify }}
  end
end
