module BentoSearch
  class Engine < ::Rails::Engine
    #isolate_namespace BentoSearch

    config.assets.precompile += %w( bento_search/large_loader.gif )
  end
end
